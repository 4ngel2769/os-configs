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
	focusGrid
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

func (m softwareModel) gridCols() int {
	const cellW = 20
	sidebarW := 24
	avail := m.width - sidebarW - 4
	if avail < cellW {
		return 1
	}
	cols := avail / cellW
	if cols < 1 {
		cols = 1
	}
	if cols > 4 {
		cols = 4
	}
	return cols
}

func (m softwareModel) appRowCol() (row, col int) {
	cols := m.gridCols()
	if cols < 1 {
		return 0, 0
	}
	return m.appIndex / cols, m.appIndex % cols
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
		m.focus = focusGrid
		m.lastPane = focusGrid
		if len(m.currentCategory().Apps) > 0 && m.appIndex >= len(m.currentCategory().Apps) {
			m.appIndex = 0
		}
		return
	}
	if m.focus == focusGrid {
		m.focus = focusSidebar
		m.lastPane = focusSidebar
	}
}

func (m *softwareModel) tabFooter() {
	if m.focus == focusFooter {
		m.focus = m.lastPane
		if m.focus != focusSidebar && m.focus != focusGrid {
			m.focus = focusSidebar
			m.lastPane = focusSidebar
		}
		return
	}
	if m.focus == focusSidebar || m.focus == focusGrid {
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
	case tickMsg:
		if m.focus == focusGrid {
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
			case focusSidebar, focusGrid:
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
			case focusGrid:
				m.togglePane()
			case focusFooter:
				m.footerButton = footerBack
				m.activateFooter()
				return m, tea.Quit
			}
			return m, nil
		case "left", "h":
			switch m.focus {
			case focusGrid:
				_, col := m.appRowCol()
				if col > 0 {
					m.appIndex--
					m.marqueeOffset = 0
				}
			case focusFooter:
				m.footerButton = footerBack
			}
			return m, nil
		case "right", "l":
			switch m.focus {
			case focusGrid:
				cols := m.gridCols()
				cat := m.currentCategory()
				_, col := m.appRowCol()
				if col < cols-1 && m.appIndex+1 < len(cat.Apps) {
					m.appIndex++
					m.marqueeOffset = 0
				}
			case focusFooter:
				m.footerButton = footerContinue
			}
			return m, nil
		case "up", "k":
			switch m.focus {
			case focusSidebar:
				if m.catIndex > 0 {
					m.catIndex--
					m.appIndex = 0
					m.marqueeOffset = 0
				}
			case focusGrid:
				cols := m.gridCols()
				if m.appIndex >= cols {
					m.appIndex -= cols
					m.marqueeOffset = 0
				}
			}
			return m, nil
		case "down", "j":
			switch m.focus {
			case focusSidebar:
				if m.catIndex < len(m.categories)-1 {
					m.catIndex++
					m.appIndex = 0
					m.marqueeOffset = 0
				}
			case focusGrid:
				cols := m.gridCols()
				cat := m.currentCategory()
				if m.appIndex+cols < len(cat.Apps) {
					m.appIndex += cols
					m.marqueeOffset = 0
				}
			}
			return m, nil
		case " ":
			if m.focus == focusGrid {
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

func (m softwareModel) renderSidebar() string {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	active := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229"))
	idle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	var b strings.Builder
	b.WriteString(headerStyle.Render("Categories"))
	if m.focus == focusSidebar {
		b.WriteString(muted.Render("  ← active"))
	}
	b.WriteString("\n")

	for i, c := range m.categories {
		count := m.selectedCount(c.ID)
		label := c.Label
		if count > 0 {
			label = fmt.Sprintf("%s (%d)", label, count)
		}
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
		b.WriteString(line)
		b.WriteString("\n")
	}
	return b.String()
}

func (m softwareModel) renderAppCell(i int, app app, cat category) string {
	const cellW = 20
	const cellH = 2

	selected := m.selected[cat.ID][app.ID]
	marker := "[ ]"
	if selected {
		marker = "[x]"
	}

	cursorExtra := 0
	isCursor := m.focus == focusGrid && i == m.appIndex
	if isCursor {
		cursorExtra = 2 // "▸ "
	}

	prefix := marker + " "
	labelW := cellW - runewidth.StringWidth(prefix) - cursorExtra
	if labelW < 4 {
		labelW = 4
	}

	var labelText string
	if isCursor {
		labelText = marqueeText(app.Label, labelW, m.marqueeOffset)
	} else {
		labelText = fadeText(app.Label, labelW)
	}

	line1 := prefix + labelText
	if isCursor {
		line1 = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229")).Render("▸ "+prefix+labelText)
	}

	noteLine := " "
	if app.Note != "" {
		noteLine = lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(fadeText(app.Note, cellW))
	}

	cell := lipgloss.JoinVertical(lipgloss.Left, line1, noteLine)
	return lipgloss.NewStyle().Width(cellW).Height(cellH).Render(cell)
}

func (m softwareModel) renderGrid() string {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	subStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	cat := m.currentCategory()
	cols := m.gridCols()

	var b strings.Builder
	title := cat.Label
	if n := m.selectedCount(cat.ID); n > 0 {
		title = fmt.Sprintf("%s — %d selected", cat.Label, n)
	}
	b.WriteString(headerStyle.Render(title))
	if m.focus == focusGrid {
		b.WriteString(subStyle.Render("  ← active"))
	}
	b.WriteString("\n\n")

	if len(cat.Apps) == 0 {
		b.WriteString(subStyle.Render("No apps in this category for your distro/platform."))
		return b.String()
	}

	for i, app := range cat.Apps {
		b.WriteString(m.renderAppCell(i, app, cat))
		if (i+1)%cols == 0 {
			b.WriteString("\n")
		}
	}
	if len(cat.Apps)%cols != 0 {
		b.WriteString("\n")
	}
	return b.String()
}

func (m softwareModel) renderFooter() string {
	gap := lipgloss.NewStyle().Width(3).Render("")

	continueStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		Padding(0, 2).
		Foreground(lipgloss.Color("10"))

	backStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		Padding(0, 2).
		Foreground(lipgloss.Color("117"))

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

	backBtn := backStyle.Render("Back")
	continueBtn := continueStyle.Render("Continue")
	return lipgloss.JoinHorizontal(lipgloss.Top, backBtn, gap, continueBtn)
}

func (m softwareModel) View() string {
	if m.err != nil {
		return fmt.Sprintf("error: %v\n", m.err)
	}
	if len(m.categories) == 0 {
		return "No compatible software for this category.\n"
	}

	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Render("os-configs")
	subTitle := lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).
		Render(fmt.Sprintf("Custom software · %d selected", m.totalSelected()))

	sidebar := lipgloss.NewStyle().Width(24).Padding(0, 1).Render(m.renderSidebar())
	grid := lipgloss.NewStyle().Padding(0, 1).Render(m.renderGrid())
	panes := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, grid)

	paneBlock := lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(panes)

	footer := m.renderFooter()
	footerBlock := lipgloss.Place(m.width, lipgloss.Height(footer)+1, lipgloss.Center, lipgloss.Center, footer)

	hint := lipgloss.NewStyle().
		Align(lipgloss.Center).
		Width(m.width).
		Foreground(lipgloss.Color("245")).
		Render("↑↓ categories · ←→ apps grid · Enter enter/leave category · Space toggle · Tab footer · Enter activate button")

	body := lipgloss.JoinVertical(
		lipgloss.Center,
		title,
		subTitle,
		"",
		paneBlock,
	)

	contentH := lipgloss.Height(body) + lipgloss.Height(footerBlock) + lipgloss.Height(hint) + 2
	topPad := (m.height - contentH) / 2
	if topPad < 0 {
		topPad = 0
	}

	main := lipgloss.JoinVertical(lipgloss.Center, body, "", footerBlock, "", hint)
	return lipgloss.NewStyle().
		Width(m.width).
		Height(m.height).
		Padding(topPad, 0, 1, 0).
		Render(main)
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
