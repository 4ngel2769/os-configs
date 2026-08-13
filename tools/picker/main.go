package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
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
}

type output struct {
	Selections map[string][]string `json:"selections"`
}

type focusArea int

const (
	focusSidebar focusArea = iota
	focusGrid
)

type model struct {
	categories   []category
	catIndex     int
	appIndex     int
	focus        focusArea
	selected     map[string]map[string]bool
	width        int
	height       int
	quitting     bool
	done         bool
	err          error
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) currentCategory() category {
	if len(m.categories) == 0 {
		return category{}
	}
	return m.categories[m.catIndex]
}

func (m model) gridCols() int {
	const minCell = 16
	if m.width < 100 {
		return 2
	}
	cols := (m.width - 28) / minCell
	if cols < 2 {
		return 2
	}
	if cols > 4 {
		return 4
	}
	return cols
}

func (m model) selectedCount(catID string) int {
	n := 0
	for _, on := range m.selected[catID] {
		if on {
			n++
		}
	}
	return n
}

func (m model) totalSelected() int {
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

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "tab", "right":
			if m.focus == focusSidebar {
				m.focus = focusGrid
				m.appIndex = 0
			} else {
				m.focus = focusSidebar
			}
			return m, nil
		case "left":
			if m.focus == focusGrid {
				m.focus = focusSidebar
			}
			return m, nil
		case "up", "k":
			if m.focus == focusSidebar && m.catIndex > 0 {
				m.catIndex--
				m.appIndex = 0
			} else if m.focus == focusGrid {
				cols := m.gridCols()
				cat := m.currentCategory()
				if m.appIndex >= cols {
					m.appIndex -= cols
				} else if m.appIndex > 0 {
					m.appIndex--
				} else if len(cat.Apps) > 0 {
					m.appIndex = len(cat.Apps) - 1
				}
			}
			return m, nil
		case "down", "j":
			if m.focus == focusSidebar && m.catIndex < len(m.categories)-1 {
				m.catIndex++
				m.appIndex = 0
			} else if m.focus == focusGrid {
				cols := m.gridCols()
				cat := m.currentCategory()
				if m.appIndex+cols < len(cat.Apps) {
					m.appIndex += cols
				} else if m.appIndex < len(cat.Apps)-1 {
					m.appIndex++
				} else {
					m.appIndex = 0
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
		case "enter":
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m model) View() string {
	if m.err != nil {
		return fmt.Sprintf("error: %v\n", m.err)
	}
	if len(m.categories) == 0 {
		return "No compatible software for this platform.\n"
	}

	var b strings.Builder

	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	subStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	sidebarStyle := lipgloss.NewStyle().Width(22).Padding(0, 1)
	gridStyle := lipgloss.NewStyle().Padding(0, 1)

	b.WriteString(headerStyle.Render("os-configs — software picker"))
	b.WriteString("\n")
	b.WriteString(subStyle.Render(fmt.Sprintf("%d selected · Tab switch pane · Space toggle · Enter finish",
		m.totalSelected())))
	b.WriteString("\n\n")

	cat := m.currentCategory()
	cols := m.gridCols()

	// Sidebar
	var sidebar strings.Builder
	sidebar.WriteString(headerStyle.Render("Categories"))
	sidebar.WriteString("\n")
	for i, c := range m.categories {
		count := m.selectedCount(c.ID)
		label := c.Label
		if count > 0 {
			label = fmt.Sprintf("%s (%d)", label, count)
		}
		line := label
		if i == m.catIndex && m.focus == focusSidebar {
			line = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229")).Render("▸ " + label)
		} else if i == m.catIndex {
			line = lipgloss.NewStyle().Foreground(lipgloss.Color("229")).Render("  " + label)
		} else {
			line = "  " + label
		}
		sidebar.WriteString(line)
		sidebar.WriteString("\n")
	}

	// Grid
	var grid strings.Builder
	title := cat.Label
	if n := m.selectedCount(cat.ID); n > 0 {
		title = fmt.Sprintf("%s — %d selected", cat.Label, n)
	}
	grid.WriteString(headerStyle.Render(title))
	grid.WriteString("\n\n")

	if len(cat.Apps) == 0 {
		grid.WriteString(subStyle.Render("No apps in this category for your distro/platform."))
	} else {
		for i, app := range cat.Apps {
			selected := m.selected[cat.ID][app.ID]
			marker := "[ ]"
			if selected {
				marker = "[x]"
			}
			cell := fmt.Sprintf("%s %s", marker, app.Label)
			isCursor := m.focus == focusGrid && i == m.appIndex
			if isCursor {
				cell = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86")).Render("▸ " + cell)
			}
			grid.WriteString(lipgloss.NewStyle().Width(18).Render(cell))
			if (i+1)%cols == 0 {
				grid.WriteString("\n")
			}
		}
		if len(cat.Apps)%cols != 0 {
			grid.WriteString("\n")
		}
	}

	left := sidebarStyle.Render(sidebar.String())
	right := gridStyle.Render(grid.String())
	b.WriteString(lipgloss.JoinHorizontal(lipgloss.Top, left, right))
	b.WriteString("\n\n")
	b.WriteString(subStyle.Render("↑↓ move · Space select · Tab/←→ sidebar/grid · Enter done · q quit"))
	return b.String()
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

func writeOutput(m model, dest *os.File) error {
	out := output{Selections: map[string][]string{}}
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

func main() {
	catalogPath := flag.String("catalog", "", "path to picker catalog JSON")
	outputPath := flag.String("output", "", "write selections JSON to this file (recommended)")
	flag.Parse()

	if *catalogPath == "" {
		fmt.Fprintln(os.Stderr, "usage: os-configs-picker --catalog /path/to/catalog.json [--output selections.json]")
		os.Exit(2)
	}

	cats, err := loadCatalog(*catalogPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	selected := map[string]map[string]bool{}
	for _, c := range cats {
		selected[c.ID] = map[string]bool{}
	}

	m := model{
		categories: cats,
		selected:   selected,
		focus:      focusSidebar,
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	fm := final.(model)
	if fm.quitting && !fm.done {
		os.Exit(1)
	}

	var dest *os.File
	if *outputPath != "" {
		dest, err = os.Create(*outputPath)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		defer dest.Close()
	} else {
		dest = os.Stdout
	}

	if err := writeOutput(fm, dest); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
