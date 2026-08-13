package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

const (
	softwareSidebarW = 24
)

type catalogFile struct {
	Categories []category `json:"categories"`
}

type category struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Apps  []app  `json:"apps"`
}

type app struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Note  string `json:"note,omitempty"`
}

type tickMsg struct{}

type softwareOutput struct {
	Selections map[string][]string `json:"selections"`
}

type focusArea int

const (
	focusSidebar focusArea = iota
	focusApps
	focusFooter
)

const (
	footerBack = iota
	footerContinue
)

type softwareModel struct {
	categories    []category
	catIndex      int
	appIndex      int
	appScroll     int
	focus         focusArea
	lastPane      focusArea
	footerButton  int
	selected      map[string]map[string]bool
	width         int
	height        int
	marqueeOffset int
	quitting      bool
	done          bool
	err           error
}

func (m softwareModel) Init() tea.Cmd {
	return tea.Tick(120*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })
}

func (m softwareModel) currentCategory() category {
	if len(m.categories) == 0 {
		return category{}
	}
	return m.categories[m.catIndex]
}

func (m softwareModel) headerView() string {
	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Render("os-configs")
	sub := lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).
		Render(fmt.Sprintf("Custom software · %d selected", m.totalSelected()))
	div := lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("240")).
		Render(strings.Repeat("─", clamp(m.width-4, 20, 100)))
	return lipgloss.JoinVertical(lipgloss.Top, title, sub, div)
}

func (m softwareModel) footerView() string {
	gap := lipgloss.NewStyle().Width(4).Render("")

	continueStyle := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(0, 2).Foreground(lipgloss.Color("10"))
	backStyle := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(0, 2).Foreground(lipgloss.Color("117"))

	if m.focus == focusFooter && m.footerButton == footerBack {
		backStyle = backStyle.Bold(true).BorderForeground(lipgloss.Color("117"))
	} else {
		backStyle = backStyle.BorderForeground(lipgloss.Color("240"))
	}
	if m.focus == focusFooter && m.footerButton == footerContinue {
		continueStyle = continueStyle.Bold(true).BorderForeground(lipgloss.Color("10"))
	} else {
		continueStyle = continueStyle.BorderForeground(lipgloss.Color("240"))
	}

	buttons := lipgloss.JoinHorizontal(lipgloss.Top, backStyle.Render("Back"), gap, continueStyle.Render("Continue"))
	return lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(buttons)
}

func (m softwareModel) hintView() string {
	return lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).
		Render("↑↓ move · Space toggle · Enter switch pane · Tab footer · c continue")
}

func (m softwareModel) bodyHeight() int {
	// m.height minus fixed header (3 lines), footer buttons (3 lines), hint (1 line), gaps (3 lines)
	h := m.height - 10
	if h < 8 {
		return 8
	}
	return h
}

func (m softwareModel) appPanelWidth() int {
	w := m.width - softwareSidebarW - 6
	if w < 34 {
		return 34
	}
	return w
}

func (m softwareModel) appVisibleLines() int {
	// Border top/bottom take 2 lines; Header line takes 1 line; Blank gap takes 1 line
	lines := m.bodyHeight() - 4
	if lines < 1 {
		return 1
	}
	return lines
}

func (m *softwareModel) ensureAppScroll() {
	visible := m.appVisibleLines()
	if visible < 1 {
		visible = 1
	}
	cat := m.currentCategory()
	total := len(cat.Apps)
	if total == 0 {
		m.appScroll = 0
		return
	}
	if m.appIndex < m.appScroll {
		m.appScroll = m.appIndex
	}
	if m.appIndex >= m.appScroll+visible {
		m.appScroll = m.appIndex - visible + 1
	}
	maxScroll := total - visible
	if maxScroll < 0 {
		maxScroll = 0
	}
	if m.appScroll > maxScroll {
		m.appScroll = maxScroll
	}
}

func (m *softwareModel) resetAppView() {
	m.appIndex = 0
	m.appScroll = 0
	m.marqueeOffset = 0
}

func (m softwareModel) selectedCount(catID string) int {
	n := 0
	for _, on := range m.selected[catID] {
		if on {
			n++
		}
	}
	return n
}

func (m softwareModel) totalSelected() int {
	n := 0
	for _, apps := range m.selected {
		for _, on := range apps {
			if on {
				n++
			}
		}
	}
	return n
}

func (m *softwareModel) togglePane() {
	if m.focus == focusSidebar {
		m.focus = focusApps
		m.lastPane = focusApps
		m.ensureAppScroll()
		return
	}
	if m.focus == focusApps {
		m.focus = focusSidebar
		m.lastPane = focusSidebar
	}
}

func (m *softwareModel) tabFooter() {
	if m.focus == focusFooter {
		m.focus = m.lastPane
		if m.focus != focusSidebar && m.focus != focusApps {
			m.focus = focusSidebar
			m.lastPane = focusSidebar
		}
		return
	}
	if m.focus == focusSidebar || m.focus == focusApps {
		m.lastPane = m.focus
		m.focus = focusFooter
		m.footerButton = footerBack
	}
}

func (m softwareModel) activateFooter() {
	if m.footerButton == footerContinue {
		m.done = true
	} else {
		m.quitting = true
	}
}

func (m softwareModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.ensureAppScroll()
		return m, nil
	case tickMsg:
		if m.focus == focusApps {
			m.marqueeOffset++
		}
		return m, tea.Tick(120*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "tab":
			m.tabFooter()
			return m, nil
		case "enter":
			switch m.focus {
			case focusSidebar, focusApps:
				m.togglePane()
			case focusFooter:
				m.activateFooter()
				return m, tea.Quit
			}
			return m, nil
		case "c":
			m.done = true
			return m, tea.Quit
		case "b":
			m.quitting = true
			return m, tea.Quit
		case "esc":
			switch m.focus {
			case focusApps:
				m.togglePane()
			case focusFooter:
				m.footerButton = footerBack
				m.activateFooter()
				return m, tea.Quit
			}
			return m, nil
		case "left", "h":
			if m.focus == focusFooter {
				m.footerButton = footerBack
			}
			return m, nil
		case "right", "l":
			if m.focus == focusFooter {
				m.footerButton = footerContinue
			}
			return m, nil
		case "up", "k":
			switch m.focus {
			case focusSidebar:
				if m.catIndex > 0 {
					m.catIndex--
					m.resetAppView()
				}
			case focusApps:
				if m.appIndex > 0 {
					m.appIndex--
					m.marqueeOffset = 0
					m.ensureAppScroll()
				}
			}
			return m, nil
		case "down", "j":
			switch m.focus {
			case focusSidebar:
				if m.catIndex < len(m.categories)-1 {
					m.catIndex++
					m.resetAppView()
				}
			case focusApps:
				cat := m.currentCategory()
				if m.appIndex+1 < len(cat.Apps) {
					m.appIndex++
					m.marqueeOffset = 0
					m.ensureAppScroll()
				}
			}
			return m, nil
		case " ":
			if m.focus == focusApps {
				cat := m.currentCategory()
				if len(cat.Apps) == 0 {
					return m, nil
				}
				if m.appIndex >= len(cat.Apps) {
					m.appIndex = 0
				}
				appID := cat.Apps[m.appIndex].ID
				if m.selected[cat.ID] == nil {
					m.selected[cat.ID] = map[string]bool{}
				}
				m.selected[cat.ID][appID] = !m.selected[cat.ID][appID]
			}
			return m, nil
		}
	}
	return m, nil
}

func (m softwareModel) renderSidebar(bodyH int) string {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	borderColor := lipgloss.Color("240")
	if m.focus == focusSidebar {
		borderColor = lipgloss.Color("86")
	}

	var lines []string
	lines = append(lines, headerStyle.Render("Categories"))
	maxLines := bodyH - 2
	if maxLines < 4 {
		maxLines = 4
	}

	for i, c := range m.categories {
		if len(lines) >= maxLines {
			break
		}
		count := m.selectedCount(c.ID)
		label := c.Label
		if count > 0 {
			label = fmt.Sprintf("%s (%d)", label, count)
		}
		label = truncateRunes(label, softwareSidebarW-4)
		prefix := "  "
		if i == m.catIndex {
			prefix = "▸ "
		}
		line := prefix + label
		switch {
		case i == m.catIndex && m.focus == focusSidebar:
			line = active.Render(line)
		case i == m.catIndex:
			line = idle.Render(line)
		default:
			line = muted.Render(line)
		}
		lines = append(lines, line)
	}

	// Pad empty lines to ensure static height
	for len(lines) < maxLines {
		lines = append(lines, "")
	}

	content := strings.Join(lines, "\n")
	box := lipgloss.NewStyle().
		Width(softwareSidebarW).
		Height(bodyH).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderColor).
		Padding(0, 1).
		Render(content)

	return box
}

func (m softwareModel) renderAppLine(idx int, item app, cat category, rowInView int, visible int, totalApps int) string {
	panelW := m.appPanelWidth()
	selected := m.selected[cat.ID][item.ID]
	marker := "[ ]"
	if selected {
		marker = "[x]"
	}

	isCursor := m.focus == focusApps && idx == m.appIndex
	note := ""
	if item.Note != "" {
		note = " · " + item.Note
	}

	noteW := runewidth.StringWidth(note)
	prefix := marker + " "
	if isCursor {
		prefix = "▸ " + marker + " "
	}
	prefixW := runewidth.StringWidth(prefix)
	labelW := panelW - prefixW - noteW - 2
	if labelW < 8 {
		labelW = 8
	}

	var label string
	if isCursor && runewidth.StringWidth(item.Label) > labelW {
		label = marqueeText(item.Label, labelW, m.marqueeOffset)
	} else {
		label = fadeText(item.Label, labelW)
	}

	line := prefix + label
	if note != "" {
		line += lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(note)
	}

	// Apply btop-style vertical list fade to edge items
	if fade := verticalFadeColor(rowInView, visible, m.appScroll, totalApps); fade != "" && !isCursor {
		line = applyFadeStyle(stripANSI(line), fade)
	} else if isCursor {
		line = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229")).Render(stripANSI(prefix)) + label
		if note != "" {
			line += lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(note)
		}
	}

	return lipgloss.NewStyle().Width(panelW).Render(line)
}

func (m softwareModel) renderAppPanel(bodyH int) string {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	subStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	borderColor := lipgloss.Color("240")
	if m.focus == focusApps {
		borderColor = lipgloss.Color("86")
	}

	cat := m.currentCategory()
	title := cat.Label
	if n := m.selectedCount(cat.ID); n > 0 {
		title = fmt.Sprintf("%s — %d selected", cat.Label, n)
	}

	var b strings.Builder
	b.WriteString(headerStyle.Render(title))
	if m.focus == focusApps {
		b.WriteString(subStyle.Render("  ← active"))
	}
	b.WriteString("\n\n")

	visible := m.appVisibleLines()
	totalApps := len(cat.Apps)

	if totalApps == 0 {
		b.WriteString(subStyle.Render("No apps in this category for your distro/platform."))
		b.WriteString("\n")
		for i := 1; i < visible; i++ {
			b.WriteString("\n")
		}
	} else {
		end := m.appScroll + visible
		if end > totalApps {
			end = totalApps
		}

		for vi, idx := range seq(m.appScroll, end) {
			b.WriteString(m.renderAppLine(idx, cat.Apps[idx], cat, vi, visible, totalApps))
			b.WriteString("\n")
		}
		// Pad remaining visible lines so panel height stays fixed.
		for i := end - m.appScroll; i < visible; i++ {
			b.WriteString("\n")
		}
	}

	panelW := m.appPanelWidth()
	box := lipgloss.NewStyle().
		Width(panelW + 2).
		Height(bodyH).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderColor).
		Padding(0, 1).
		Render(b.String())

	return box
}

func (m softwareModel) bodyView(bodyH int) string {
	sidebar := m.renderSidebar(bodyH)
	apps := m.renderAppPanel(bodyH)
	row := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, "  ", apps)
	return lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(row)
}

func (m softwareModel) View() string {
	if m.err != nil {
		return fmt.Sprintf("error: %v\n", m.err)
	}
	if len(m.categories) == 0 {
		return "No compatible software for this category.\n"
	}

	w := m.width
	if w < 40 {
		w = 40
	}
	h := m.height
	if h < 16 {
		h = 16
	}

	header := m.headerView()
	footer := m.footerView()
	hint := m.hintView()
	bodyH := m.bodyHeight()
	body := m.bodyView(bodyH)

	fullContent := lipgloss.JoinVertical(lipgloss.Center, header, "", body, "", footer, "", hint)

	// Lock entire frame to exact terminal window size to eliminate all layout shift
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Top, fullContent)
}

func loadCatalog(path string) ([]category, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cf catalogFile
	if err := json.Unmarshal(raw, &cf); err != nil {
		return nil, err
	}
	return cf.Categories, nil
}

func writeSoftwareOutput(m softwareModel, dest *os.File) error {
	out := softwareOutput{Selections: map[string][]string{}}
	for catID, apps := range m.selected {
		var ids []string
		for id, on := range apps {
			if on {
				ids = append(ids, id)
			}
		}
		if len(ids) > 0 {
			sort.Strings(ids)
			out.Selections[catID] = ids
		}
	}
	enc := json.NewEncoder(dest)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}

func runSoftwarePicker(catalogPath, outputPath string) error {
	cats, err := loadCatalog(catalogPath)
	if err != nil {
		return err
	}

	selected := map[string]map[string]bool{}
	for _, c := range cats {
		selected[c.ID] = map[string]bool{}
	}

	m := softwareModel{
		categories:   cats,
		selected:     selected,
		focus:        focusSidebar,
		lastPane:     focusSidebar,
		footerButton: footerBack,
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}

	fm := final.(softwareModel)
	if fm.quitting && !fm.done {
		os.Exit(1)
	}

	dest, err := openOutput(outputPath)
	if err != nil {
		return err
	}
	defer dest.Close()

	return writeSoftwareOutput(fm, dest)
}
