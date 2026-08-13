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
	softwareSidebarW = 28
	softwareGapW     = 2
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

func (m softwareModel) currentCategory() category {
	if len(m.categories) == 0 {
		return category{}
	}
	return m.categories[m.catIndex]
}

func (m softwareModel) headerView() string {
	w := m.width
	if w < 40 {
		w = 40
	}
	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(w).Render("os-configs")
	sub := lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("245")).
		Render(fmt.Sprintf("Custom software · %d selected", m.totalSelected()))
	div := lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("240")).
		Render(strings.Repeat("─", clamp(w-4, 20, 100)))

	parts := []string{title, sub, div}
	if m.banner != nil {
		parts = append(parts, renderDetectionStrip(w, *m.banner))
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

func panelInnerWidth(outerW int) int {
	// border (2) + horizontal padding (2)
	return outerW - 4
}

func panelListRows(panelH int) int {
	// border (2) + title row (1)
	n := panelH - 3
	if n < 1 {
		return 1
	}
	return n
}

func renderPanel(title string, lines []string, outerW, outerH int, focused bool) string {
	borderColor := lipgloss.Color("240")
	if focused {
		borderColor = lipgloss.Color("86")
	}

	innerW := panelInnerWidth(outerW)
	listRows := panelListRows(outerH)

	titleLine := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86")).
		Render(truncateRunes(title, innerW))
	body := strings.Join(padLines(lines, listRows), "\n")
	inner := lipgloss.JoinVertical(lipgloss.Left, titleLine, body)

	return lipgloss.NewStyle().
		Width(outerW).
		Height(outerH).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderColor).
		Padding(0, 1).
		Render(inner)
}

func (m softwareModel) appsPanelW() int {
	w := m.width - softwareSidebarW - softwareGapW
	if w < 32 {
		return 32
	}
	return w
}

func (m *softwareModel) clampScroll(listRows, total int, scroll, index *int) {
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
	if *index >= *scroll+listRows {
		*scroll = *index - listRows + 1
	}
	maxScroll := total - listRows
	if maxScroll < 0 {
		maxScroll = 0
	}
	if *scroll > maxScroll {
		*scroll = maxScroll
	}
}

func (m softwareModel) sidebarLines(listRows int) []string {
	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	innerW := panelInnerWidth(softwareSidebarW)

	var lines []string
	end := m.catScroll + listRows
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
		text := truncateRunes(prefix+label, innerW)
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

func (m softwareModel) appLines(listRows int) []string {
	cat := m.currentCategory()
	innerW := panelInnerWidth(m.appsPanelW())

	if len(cat.Apps) == 0 {
		return []string{
			lipgloss.NewStyle().Foreground(lipgloss.Color("245")).
				Render(truncateRunes("No apps for your distro/platform.", innerW)),
		}
	}

	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	noteStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("240"))

	end := m.appScroll + listRows
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

		prefixPlain := prefix
		labelPlain := item.Label
		notePlain := ""
		if item.Note != "" {
			notePlain = " · " + item.Note
		}

		budget := innerW - runewidth.StringWidth(prefixPlain) - runewidth.StringWidth(notePlain)
		if budget < 4 {
			budget = 4
		}
		labelPlain = truncateRunes(labelPlain, budget)

		text := prefixPlain + labelPlain + notePlain
		text = truncateRunes(text, innerW)

		isCursor := m.focus == focusApps && i == m.appIndex
		switch {
		case isCursor:
			lines = append(lines, active.Render(text))
		default:
			if notePlain != "" {
				lines = append(lines, idle.Render(prefixPlain+labelPlain)+noteStyle.Render(notePlain))
			} else {
				lines = append(lines, idle.Render(text))
			}
		}
	}
	return lines
}

func (m softwareModel) bodyView(bodyH int) string {
	listRows := panelListRows(bodyH)

	cat := m.currentCategory()
	appTitle := cat.Label
	if n := m.selectedCount(cat.ID); n > 0 {
		appTitle = fmt.Sprintf("%s — %d selected", cat.Label, n)
	}

	sidebar := renderPanel("Categories", m.sidebarLines(listRows), softwareSidebarW, bodyH, m.focus == focusSidebar)
	apps := renderPanel(appTitle, m.appLines(listRows), m.appsPanelW(), bodyH, m.focus == focusApps)
	gap := lipgloss.NewStyle().Width(softwareGapW).Render("")

	row := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, gap, apps)
	return lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(row)
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

func (m softwareModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		bodyH := m.bodyHeight()
		listRows := panelListRows(bodyH)

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
					m.clampScroll(listRows, len(m.categories), &m.catScroll, &m.catIndex)
				}
			case focusApps:
				if m.appIndex > 0 {
					m.appIndex--
					m.clampScroll(listRows, len(m.currentCategory().Apps), &m.appScroll, &m.appIndex)
				}
			}
			return m, nil
		case "down", "j":
			switch m.focus {
			case focusSidebar:
				if m.catIndex+1 < len(m.categories) {
					m.catIndex++
					m.resetApps()
					m.clampScroll(listRows, len(m.categories), &m.catScroll, &m.catIndex)
				}
			case focusApps:
				cat := m.currentCategory()
				if m.appIndex+1 < len(cat.Apps) {
					m.appIndex++
					m.clampScroll(listRows, len(cat.Apps), &m.appScroll, &m.appIndex)
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
