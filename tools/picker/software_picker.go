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

const (
	softwareCellW = 20
	softwareCellH = 2
	softwareSideW = 24
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
	gridScrollRow int
	sidebarScroll int
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

func (m softwareModel) paneHeight() int {
	// title(2) + gap + footer(3) + hint(1) + padding(2)
	h := m.height - 10
	if h < 8 {
		return 8
	}
	return h
}

func (m softwareModel) gridCols() int {
	avail := m.width - softwareSideW - 6
	if avail < softwareCellW {
		return 1
	}
	cols := avail / softwareCellW
	if cols < 1 {
		cols = 1
	}
	if cols > 4 {
		cols = 4
	}
	return cols
}

func (m softwareModel) gridVisibleRows() int {
	body := m.paneHeight() - 2 // grid title + spacer
	if body < softwareCellH {
		return 1
	}
	return body / softwareCellH
}

func (m softwareModel) sidebarVisibleRows() int {
	body := m.paneHeight() - 1 // "Categories" header
	if body < 1 {
		return 1
	}
	return body
}

func (m softwareModel) gridTotalRows() int {
	cols := m.gridCols()
	cat := m.currentCategory()
	if cols < 1 || len(cat.Apps) == 0 {
		return 0
	}
	return (len(cat.Apps) + cols - 1) / cols
}

func (m softwareModel) appRowCol() (row, col int) {
	cols := m.gridCols()
	if cols < 1 {
		return 0, 0
	}
	return m.appIndex / cols, m.appIndex % cols
}

func (m *softwareModel) ensureGridScroll() {
	cols := m.gridCols()
	if cols < 1 {
		return
	}
	cursorRow := m.appIndex / cols
	visible := m.gridVisibleRows()
	total := m.gridTotalRows()
	if visible < 1 {
		visible = 1
	}
	if cursorRow < m.gridScrollRow {
		m.gridScrollRow = cursorRow
	}
	if cursorRow >= m.gridScrollRow+visible {
		m.gridScrollRow = cursorRow - visible + 1
	}
	maxScroll := total - visible
	if maxScroll < 0 {
		maxScroll = 0
	}
	if m.gridScrollRow > maxScroll {
		m.gridScrollRow = maxScroll
	}
}

func (m *softwareModel) ensureSidebarScroll() {
	visible := m.sidebarVisibleRows()
	if m.catIndex < m.sidebarScroll {
		m.sidebarScroll = m.catIndex
	}
	if m.catIndex >= m.sidebarScroll+visible {
		m.sidebarScroll = m.catIndex - visible + 1
	}
	maxScroll := len(m.categories) - visible
	if maxScroll < 0 {
		maxScroll = 0
	}
	if m.sidebarScroll > maxScroll {
		m.sidebarScroll = maxScroll
	}
}

func (m *softwareModel) resetCategoryView() {
	m.appIndex = 0
	m.gridScrollRow = 0
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
		m.focus = focusGrid
		m.lastPane = focusGrid
		if len(m.currentCategory().Apps) > 0 && m.appIndex >= len(m.currentCategory().Apps) {
			m.appIndex = 0
		}
		m.ensureGridScroll()
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
		m.ensureGridScroll()
		m.ensureSidebarScroll()
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
					m.ensureGridScroll()
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
					m.ensureGridScroll()
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
					m.resetCategoryView()
					m.ensureSidebarScroll()
				}
			case focusGrid:
				cols := m.gridCols()
				if m.appIndex >= cols {
					m.appIndex -= cols
					m.marqueeOffset = 0
					m.ensureGridScroll()
				}
			}
			return m, nil
		case "down", "j":
			switch m.focus {
			case focusSidebar:
				if m.catIndex < len(m.categories)-1 {
					m.catIndex++
					m.resetCategoryView()
					m.ensureSidebarScroll()
				}
			case focusGrid:
				cols := m.gridCols()
				cat := m.currentCategory()
				if m.appIndex+cols < len(cat.Apps) {
					m.appIndex += cols
					m.marqueeOffset = 0
					m.ensureGridScroll()
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

	visible := m.sidebarVisibleRows()
	start := m.sidebarScroll
	end := start + visible
	if end > len(m.categories) {
		end = len(m.categories)
	}
	rowsBelow := len(m.categories) - end

	for vi, i := range seq(start, end) {
		c := m.categories[i]
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
		fade := verticalFadeColor(vi, end-start, rowsBelow)
		switch {
		case i == m.catIndex && m.focus == focusSidebar:
			line = active.Render(line)
		case i == m.catIndex:
			line = idle.Render(line)
		case fade != "":
			line = applyFadeStyle(line, fade)
		default:
			line = muted.Render(line)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}

	// Pad to fixed height.
	for i := end - start; i < visible; i++ {
		b.WriteString("\n")
	}
	return b.String()
}

func stripANSI(s string) string {
	// Simple fallback: rebuild from runes if already plain.
	if !strings.Contains(s, "\x1b") {
		return s
	}
	var b strings.Builder
	esc := false
	for _, r := range s {
		if esc {
			if r == 'm' {
				esc = false
			}
			continue
		}
		if r == '\x1b' {
			esc = true
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

func seq(start, end int) []int {
	if end <= start {
		return nil
	}
	out := make([]int, end-start)
	for i := range out {
		out[i] = start + i
	}
	return out
}

func (m softwareModel) renderAppCell(i int, app app, cat category, rowFade lipgloss.Color) string {
	selected := m.selected[cat.ID][app.ID]
	marker := "[ ]"
	if selected {
		marker = "[x]"
	}

	cursorExtra := 0
	isCursor := m.focus == focusGrid && i == m.appIndex
	if isCursor {
		cursorExtra = 2
	}

	prefix := marker + " "
	labelW := softwareCellW - runewidth.StringWidth(prefix) - cursorExtra
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
		line1 = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229")).Render("▸ " + prefix + stripANSI(labelText))
	} else if rowFade != "" {
		line1 = applyFadeStyle(prefix+truncateRunes(app.Label, labelW), rowFade)
	}

	noteLine := " "
	if app.Note != "" {
		if rowFade != "" {
			noteLine = applyFadeStyle(truncateRunes(app.Note, softwareCellW), rowFade)
		} else {
			noteLine = lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(fadeText(app.Note, softwareCellW))
		}
	}

	cell := lipgloss.JoinVertical(lipgloss.Left, line1, noteLine)
	return lipgloss.NewStyle().Width(softwareCellW).Height(softwareCellH).Render(cell)
}

func (m softwareModel) renderGrid() string {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	subStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	cat := m.currentCategory()
	cols := m.gridCols()
	visibleRows := m.gridVisibleRows()
	totalRows := m.gridTotalRows()

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
		for i := 0; i < visibleRows-1; i++ {
			b.WriteString("\n")
		}
		return b.String()
	}

	rowsBelow := totalRows - (m.gridScrollRow + visibleRows)
	if rowsBelow < 0 {
		rowsBelow = 0
	}

	for vr := 0; vr < visibleRows; vr++ {
		actualRow := m.gridScrollRow + vr
		rowFade := verticalFadeColor(vr, visibleRows, rowsBelow)

		if actualRow >= totalRows {
			b.WriteString(strings.Repeat(" ", cols*softwareCellW))
			if vr < visibleRows-1 {
				b.WriteString("\n")
			}
			continue
		}

		for col := 0; col < cols; col++ {
			idx := actualRow*cols + col
			if idx >= len(cat.Apps) {
				b.WriteString(lipgloss.NewStyle().Width(softwareCellW).Render(""))
			} else {
				b.WriteString(m.renderAppCell(idx, cat.Apps[idx], cat, rowFade))
			}
		}
		if vr < visibleRows-1 {
			b.WriteString("\n")
		}
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

	paneH := m.paneHeight()

	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Render("os-configs")
	subTitle := lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).
		Render(fmt.Sprintf("Custom software · %d selected", m.totalSelected()))

	sidebar := lipgloss.NewStyle().
		Width(softwareSideW).
		Height(paneH).
		Padding(0, 1).
		Render(m.renderSidebar())

	grid := lipgloss.NewStyle().
		Height(paneH).
		Padding(0, 1).
		Render(m.renderGrid())

	panes := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, grid)
	paneBlock := lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(panes)

	footer := m.renderFooter()
	footerBlock := lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Margin(1, 0).Render(footer)

	hint := lipgloss.NewStyle().
		Align(lipgloss.Center).
		Width(m.width).
		Foreground(lipgloss.Color("245")).
		Render("↑↓ navigate · ←→ move · Enter enter/leave · Space toggle · Tab footer")

	main := lipgloss.JoinVertical(lipgloss.Center, title, subTitle, "", paneBlock, footerBlock, hint)
	return lipgloss.NewStyle().
		Width(m.width).
		Height(m.height).
		Padding(1, 0, 0, 0).
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
