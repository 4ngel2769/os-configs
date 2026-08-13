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
	softwareSidebarW = 26
	softwarePanelGap = 2
)

type catalogFile struct {
	Banner     *bannerInfo `json:"banner,omitempty"`
	Categories []category  `json:"categories"`
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
	banner        *bannerInfo
	categories    []category
	catIndex      int
	catScroll     int
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

type softwareLayout struct {
	sidebarW int
	appsW    int
	bodyH    int
	listRows int
}

func (m softwareModel) computeLayout() softwareLayout {
	sidebarW := softwareSidebarW
	gap := softwarePanelGap
	appsW := m.width - sidebarW - gap
	if appsW < 34 {
		appsW = 34
	}
	if sidebarW+gap+appsW > m.width {
		appsW = m.width - sidebarW - gap
		if appsW < 28 {
			appsW = 28
		}
	}

	bannerLines := 0
	if m.banner != nil {
		bannerLines = 1
	}
	// header 3 + banner + gaps 3 + footer 3 + hint 1 + padding 2
	chrome := 3 + bannerLines + 3 + 3 + 1 + 2
	bodyH := m.height - chrome
	if bodyH < 10 {
		bodyH = 10
	}
	listRows := bodyH - 2 - 1
	if listRows < 5 {
		listRows = 5
	}
	return softwareLayout{sidebarW: sidebarW, appsW: appsW, bodyH: bodyH, listRows: listRows}
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
	parts := []string{title, sub, div}
	if m.banner != nil {
		parts = append(parts, renderDetectionStrip(m.width, *m.banner))
	}
	return lipgloss.JoinVertical(lipgloss.Top, parts...)
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

func (m *softwareModel) ensureAppScroll(layout softwareLayout) {
	visible := layout.listRows
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

func (m *softwareModel) ensureCatScroll(layout softwareLayout) {
	visible := layout.listRows
	total := len(m.categories)
	if total == 0 {
		m.catScroll = 0
		return
	}
	if m.catIndex < m.catScroll {
		m.catScroll = m.catIndex
	}
	if m.catIndex >= m.catScroll+visible {
		m.catScroll = m.catIndex - visible + 1
	}
	maxScroll := total - visible
	if maxScroll < 0 {
		maxScroll = 0
	}
	if m.catScroll > maxScroll {
		m.catScroll = maxScroll
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
	layout := m.computeLayout()

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.ensureAppScroll(layout)
		m.ensureCatScroll(layout)
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
					m.ensureCatScroll(layout)
				}
			case focusApps:
				if m.appIndex > 0 {
					m.appIndex--
					m.marqueeOffset = 0
					m.ensureAppScroll(layout)
				}
			}
			return m, nil
		case "down", "j":
			switch m.focus {
			case focusSidebar:
				if m.catIndex < len(m.categories)-1 {
					m.catIndex++
					m.resetAppView()
					m.ensureCatScroll(layout)
				}
			case focusApps:
				cat := m.currentCategory()
				if m.appIndex+1 < len(cat.Apps) {
					m.appIndex++
					m.marqueeOffset = 0
					m.ensureAppScroll(layout)
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

func (m softwareModel) renderSidebarLines(layout softwareLayout) []string {
	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	innerW := layout.sidebarW - 4
	if innerW < 10 {
		innerW = 10
	}

	var lines []string
	end := m.catScroll + layout.listRows
	if end > len(m.categories) {
		end = len(m.categories)
	}
	for i := m.catScroll; i < end; i++ {
		c := m.categories[i]
		count := m.selectedCount(c.ID)
		label := c.Label
		if count > 0 {
			label = fmt.Sprintf("%s (%d)", label, count)
		}
		label = truncateRunes(label, innerW-2)
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
		lines = append(lines, lipgloss.NewStyle().Width(innerW).Render(line))
	}
	return lines
}

func (m softwareModel) renderAppLine(idx int, item app, cat category, rowInView int, layout softwareLayout) string {
	innerW := layout.appsW - 4
	if innerW < 12 {
		innerW = 12
	}

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
	prefixW := runewidth.StringWidth(stripANSI(prefix))
	labelW := innerW - prefixW - noteW
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

	totalApps := len(cat.Apps)
	if fade := verticalFadeColor(rowInView, layout.listRows, m.appScroll, totalApps); fade != "" && !isCursor {
		line = applyFadeStyle(stripANSI(line), fade)
	} else if isCursor {
		line = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229")).Render(stripANSI(prefix)) + label
		if note != "" {
			line += lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(note)
		}
	}

	return lipgloss.NewStyle().Width(innerW).Render(line)
}

func (m softwareModel) renderAppLines(layout softwareLayout) []string {
	cat := m.currentCategory()
	if len(cat.Apps) == 0 {
		msg := lipgloss.NewStyle().Foreground(lipgloss.Color("245")).Render("No apps in this category for your distro/platform.")
		return []string{msg}
	}

	end := m.appScroll + layout.listRows
	if end > len(cat.Apps) {
		end = len(cat.Apps)
	}

	var lines []string
	for vi, idx := range seq(m.appScroll, end) {
		lines = append(lines, m.renderAppLine(idx, cat.Apps[idx], cat, vi, layout))
	}
	return lines
}

func (m softwareModel) bodyView(layout softwareLayout) string {
	cat := m.currentCategory()
	appTitle := cat.Label
	if n := m.selectedCount(cat.ID); n > 0 {
		appTitle = fmt.Sprintf("%s — %d selected", cat.Label, n)
	}
	appSubtitle := ""
	if m.focus == focusApps {
		appSubtitle = "active"
	}

	sidebar := borderedPanel{
		title:   "Categories",
		lines:   m.renderSidebarLines(layout),
		width:   layout.sidebarW,
		height:  layout.bodyH,
		focused: m.focus == focusSidebar,
	}.render()

	apps := borderedPanel{
		title:    appTitle,
		lines:    m.renderAppLines(layout),
		width:    layout.appsW,
		height:   layout.bodyH,
		focused:  m.focus == focusApps,
		subtitle: appSubtitle,
	}.render()

	gap := lipgloss.NewStyle().Width(softwarePanelGap).Render("")
	row := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, gap, apps)
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
	if h < 18 {
		h = 18
	}

	layout := m.computeLayout()
	header := m.headerView()
	body := m.bodyView(layout)
	footer := m.footerView()
	hint := m.hintView()

	fullContent := lipgloss.JoinVertical(lipgloss.Center, header, "", body, "", footer, "", hint)
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Top, fullContent)
}

func loadCatalog(path string) ([]category, *bannerInfo, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, err
	}
	var cf catalogFile
	if err := json.Unmarshal(raw, &cf); err != nil {
		return nil, nil, err
	}
	return cf.Categories, cf.Banner, nil
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
	cats, banner, err := loadCatalog(catalogPath)
	if err != nil {
		return err
	}

	selected := map[string]map[string]bool{}
	for _, c := range cats {
		selected[c.ID] = map[string]bool{}
	}

	m := softwareModel{
		banner:       banner,
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
