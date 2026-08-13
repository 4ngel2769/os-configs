package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

const (
	softwareSidebarW = 24
	softwareGapW     = 3
)

type catalogFile struct {
	Banner     *bannerInfo `json:"banner,omitempty"`
	Title      string      `json:"title,omitempty"`
	Subtitle   string      `json:"subtitle,omitempty"`
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
	banner       *bannerInfo
	title        string
	subtitle     string
	categories   []category
	catIndex     int
	catScroll    int
	appIndex     int
	appScroll    int
	focus        focusArea
	lastPane     focusArea
	footerButton int
	selected     map[string]map[string]bool
	width        int
	height       int
	quitting     bool
	done         bool
	err          error
}

func (m softwareModel) Init() tea.Cmd { return nil }

func (m softwareModel) termW() int {
	if m.width < 60 {
		return 60
	}
	return m.width
}

func (m softwareModel) appsColW() int {
	w := m.termW() - softwareSidebarW - softwareGapW
	if w < 28 {
		return 28
	}
	return w
}

func (m softwareModel) listRows(bodyH int) int {
	// title + rule + list
	n := bodyH - 2
	if n < 4 {
		return 4
	}
	return n
}

func (m softwareModel) currentCategory() category {
	if len(m.categories) == 0 {
		return category{}
	}
	return m.categories[m.catIndex]
}

func (m softwareModel) headerView() string {
	w := m.termW()
	titleText := strings.TrimSpace(m.title)
	if titleText == "" {
		titleText = tuiString("software_main_title", "Custom software")
	}
	subtitleText := strings.TrimSpace(m.subtitle)
	if subtitleText == "" {
		subtitleText = fmt.Sprintf("%d selected", m.totalSelected())
	} else {
		subtitleText = fmt.Sprintf("%s · %d selected", subtitleText, m.totalSelected())
	}

	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(w).Render("os-configs")
	sub := lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("245")).
		Render(fmt.Sprintf("%s · %s", titleText, subtitleText))
	div := lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("240")).
		Render(strings.Repeat("─", clamp(w-4, 20, 100)))

	parts := []string{title, sub, div}
	if m.banner != nil {
		parts = append(parts, renderDetectionStrip(w, *m.banner))
	}
	return lipgloss.JoinVertical(lipgloss.Top, parts...)
}

func (m softwareModel) footerView() string {
	w := m.termW()
	backLabel := tuiString("button_back", "Back")
	continueLabel := tuiString("button_continue", "Continue")
	buttons := renderButtonRow(backLabel, continueLabel, m.focus == focusFooter && m.footerButton == footerBack, buttonSecondary, buttonPrimary, 4)
	return centerBlock(w, buttons)
}

func (m softwareModel) hintView() string {
	return lipgloss.NewStyle().Align(lipgloss.Center).Width(m.termW()).Foreground(appTUI.Theme.muted()).
		Render(tuiString("software_hint", "↑↓ move · Space toggle · Enter switch pane · Tab footer · c continue"))
}

func padLine(s string, width int) string {
	if width < 1 {
		return s
	}
	vis := runewidth.StringWidth(stripANSI(s))
	if vis >= width {
		return s
	}
	return s + strings.Repeat(" ", width-vis)
}

func renderColumn(title string, lines []string, colW, rows int, focused bool) string {
	titleColor := lipgloss.Color("245")
	if focused {
		titleColor = lipgloss.Color("86")
	}
	titleLine := lipgloss.NewStyle().Bold(true).Foreground(titleColor).
		Render(padLine(truncateRunes(title, colW), colW))
	rule := lipgloss.NewStyle().Foreground(lipgloss.Color("240")).
		Render(strings.Repeat("─", colW))

	out := []string{titleLine, rule}
	for i := 0; i < rows; i++ {
		line := ""
		if i < len(lines) {
			line = lines[i]
		}
		out = append(out, padLine(line, colW))
	}
	return strings.Join(out, "\n")
}

func (m *softwareModel) clampScroll(rows, total int, scroll, index *int) {
	if total <= 0 {
		*scroll = 0
		*index = 0
		return
	}
	if *index >= total {
		*index = total - 1
	}
	if *index < *scroll {
		*scroll = *index
	}
	if *index >= *scroll+rows {
		*scroll = *index - rows + 1
	}
	maxScroll := total - rows
	if maxScroll < 0 {
		maxScroll = 0
	}
	if *scroll > maxScroll {
		*scroll = maxScroll
	}
}

func (m softwareModel) sidebarLines(rows int) []string {
	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	var lines []string
	end := m.catScroll + rows
	if end > len(m.categories) {
		end = len(m.categories)
	}
	for i := m.catScroll; i < end; i++ {
		c := m.categories[i]
		label := c.Label
		if n := m.selectedCount(c.ID); n > 0 {
			label = fmt.Sprintf("%s (%d)", label, n)
		}
		prefix := "  "
		if i == m.catIndex {
			prefix = "▸ "
		}
		text := truncateRunes(prefix+label, softwareSidebarW)
		switch {
		case i == m.catIndex && m.focus == focusSidebar:
			lines = append(lines, active.Render(text))
		case i == m.catIndex:
			lines = append(lines, idle.Render(text))
		default:
			lines = append(lines, muted.Render(text))
		}
	}
	return lines
}

func (m softwareModel) appLines(rows int) []string {
	cat := m.currentCategory()
	colW := m.appsColW()

	if len(cat.Apps) == 0 {
		return []string{
			lipgloss.NewStyle().Foreground(lipgloss.Color("245")).
				Render(truncateRunes("No apps for your distro/platform.", colW)),
		}
	}

	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))

	end := m.appScroll + rows
	if end > len(cat.Apps) {
		end = len(cat.Apps)
	}

	var lines []string
	for i := m.appScroll; i < end; i++ {
		item := cat.Apps[i]
		marker := "[ ]"
		if m.selected[cat.ID][item.ID] {
			marker = "[x]"
		}
		prefix := "  " + marker + " "
		if m.focus == focusApps && i == m.appIndex {
			prefix = "▸ " + marker + " "
		}
		text := truncateRunes(prefix+item.Label, colW)
		if m.focus == focusApps && i == m.appIndex {
			lines = append(lines, active.Render(text))
		} else {
			lines = append(lines, idle.Render(text))
		}
	}
	return lines
}

func (m softwareModel) bodyView(bodyH int) string {
	rows := m.listRows(bodyH)

	cat := m.currentCategory()
	appTitle := cat.Label
	if n := m.selectedCount(cat.ID); n > 0 {
		appTitle = fmt.Sprintf("%s — %d selected", cat.Label, n)
	}

	left := renderColumn("Categories", m.sidebarLines(rows), softwareSidebarW, rows, m.focus == focusSidebar)
	right := renderColumn(appTitle, m.appLines(rows), m.appsColW(), rows, m.focus == focusApps)
	gap := strings.Repeat(" ", softwareGapW)

	row := lipgloss.JoinHorizontal(lipgloss.Top, left, gap, right)
	return lipgloss.NewStyle().Width(m.termW()).Align(lipgloss.Center).Render(row)
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

func (m *softwareModel) resetApps() {
	m.appIndex = 0
	m.appScroll = 0
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

func (m softwareModel) bodyHeight() int {
	h := m.height
	if h < 18 {
		h = 18
	}
	header := m.headerView()
	footer := m.footerView()
	hint := m.hintView()
	bodyH := h - lipgloss.Height(header) - lipgloss.Height(footer) - lipgloss.Height(hint)
	if bodyH < 8 {
		return 8
	}
	return bodyH
}

func (m softwareModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		rows := m.listRows(m.bodyHeight())

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
					m.resetApps()
					m.clampScroll(rows, len(m.categories), &m.catScroll, &m.catIndex)
				}
			case focusApps:
				if m.appIndex > 0 {
					m.appIndex--
					m.clampScroll(rows, len(m.currentCategory().Apps), &m.appScroll, &m.appIndex)
				}
			}
			return m, nil
		case "down", "j":
			switch m.focus {
			case focusSidebar:
				if m.catIndex+1 < len(m.categories) {
					m.catIndex++
					m.resetApps()
					m.clampScroll(rows, len(m.categories), &m.catScroll, &m.catIndex)
				}
			case focusApps:
				cat := m.currentCategory()
				if m.appIndex+1 < len(cat.Apps) {
					m.appIndex++
					m.clampScroll(rows, len(cat.Apps), &m.appScroll, &m.appIndex)
				}
			}
			return m, nil
		case " ":
			if m.focus != focusApps {
				return m, nil
			}
			cat := m.currentCategory()
			if len(cat.Apps) == 0 || m.appIndex >= len(cat.Apps) {
				return m, nil
			}
			id := cat.Apps[m.appIndex].ID
			if m.selected[cat.ID] == nil {
				m.selected[cat.ID] = map[string]bool{}
			}
			m.selected[cat.ID][id] = !m.selected[cat.ID][id]
			return m, nil
		}
	}
	return m, nil
}

func (m softwareModel) View() string {
	if m.err != nil {
		return fmt.Sprintf("error: %v\n", m.err)
	}
	if len(m.categories) == 0 {
		return "No compatible software for this category.\n"
	}

	header := m.headerView()
	footer := m.footerView()
	hint := m.hintView()
	body := m.bodyView(m.bodyHeight())

	return lipgloss.JoinVertical(lipgloss.Top, header, body, footer, hint)
}

func loadCatalog(path string) ([]category, *bannerInfo, string, string, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, "", "", err
	}
	var cf catalogFile
	if err := json.Unmarshal(raw, &cf); err != nil {
		return nil, nil, "", "", err
	}
	return cf.Categories, cf.Banner, cf.Title, cf.Subtitle, nil
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
	cats, banner, title, subtitle, err := loadCatalog(catalogPath)
	if err != nil {
		return err
	}

	selected := map[string]map[string]bool{}
	for _, c := range cats {
		selected[c.ID] = map[string]bool{}
	}

	m := softwareModel{
		banner:       banner,
		title:        title,
		subtitle:     subtitle,
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
