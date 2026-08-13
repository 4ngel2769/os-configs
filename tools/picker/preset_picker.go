package main

import (
	"encoding/json"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

type presetOption struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Subtitle string `json:"subtitle,omitempty"`
}

type presetInput struct {
	DistroID     string         `json:"distro_id"`
	DistroLabel  string         `json:"distro_label"`
	DistroColor  string         `json:"distro_color"`
	Presets      []presetOption `json:"presets"`
	Custom       presetOption   `json:"custom"`
}

type presetOutput struct {
	Choice string `json:"choice"`
}

type presetModel struct {
	input    presetInput
	items    []presetOption
	cursor   int
	width    int
	height   int
	cardW    int
	quitting bool
	done     bool
}

func loadPresetInput(path string) (presetInput, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return presetInput{}, err
	}
	var in presetInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return presetInput{}, err
	}
	return in, nil
}

func (m presetModel) Init() tea.Cmd { return nil }

func (m presetModel) itemCount() int { return len(m.items) }

func (m presetModel) gridCols() int {
	gap := 2
	if m.width < 1 {
		return 1
	}
	cols := (m.width - 2) / (m.cardW + gap)
	if cols < 1 {
		cols = 1
	}
	if cols > m.itemCount() {
		cols = m.itemCount()
	}
	return cols
}

func truncate(s string, max int) string {
	if runewidth.StringWidth(s) <= max {
		return s
	}
	out := ""
	for _, r := range s {
		next := out + string(r)
		if runewidth.StringWidth(next)+1 > max {
			return out + "…"
		}
		out = next
	}
	return out
}

func (m presetModel) renderCard(idx int) string {
	item := m.items[idx]
	selected := idx == m.cursor

	borderColor := lipgloss.Color("240")
	nameColor := lipgloss.Color("252")

	if selected {
		borderColor = lipgloss.Color("86")
		nameColor = lipgloss.Color("255")
	}

	innerW := m.cardW - 2
	name := truncate(item.Label, innerW)
	sub := item.Subtitle
	if sub == "" {
		sub = m.input.DistroLabel
	}
	sub = truncate(sub, innerW)

	nameLine := lipgloss.NewStyle().
		Width(innerW).
		Align(lipgloss.Center).
		Foreground(nameColor).
		Render(name)

	subStyle := lipgloss.NewStyle().
		Width(innerW).
		Align(lipgloss.Center).
		Foreground(lipgloss.Color("245"))

	if item.Subtitle == "" && m.input.DistroColor != "" {
		subStyle = subStyle.Foreground(lipgloss.Color(m.input.DistroColor))
	}
	subLine := subStyle.Render(sub)

	inner := lipgloss.JoinVertical(lipgloss.Center, nameLine, subLine)

	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderColor).
		Width(m.cardW).
		Padding(0, 1).
		Render(inner)

	if selected {
		box = lipgloss.NewStyle().Bold(true).Render(box)
	}
	return box
}

func (m presetModel) renderGrid() string {
	cols := m.gridCols()
	gap := lipgloss.NewStyle().Width(2).Render("")

	var rows []string
	for i := 0; i < m.itemCount(); i += cols {
		var cells []string
		for j := 0; j < cols && i+j < m.itemCount(); j++ {
			cells = append(cells, m.renderCard(i+j))
		}
		row := lipgloss.JoinHorizontal(lipgloss.Top, interleave(cells, gap)...)
		rows = append(rows, lipgloss.Place(m.width, lipgloss.Height(row), lipgloss.Center, lipgloss.Top, row))
	}
	return lipgloss.JoinVertical(lipgloss.Left, rows...)
}

func interleave(cells []string, gap string) []string {
	if len(cells) == 0 {
		return cells
	}
	out := []string{cells[0]}
	for i := 1; i < len(cells); i++ {
		out = append(out, gap, cells[i])
	}
	return out
}

func (m presetModel) computeCardWidth() int {
	max := 18
	for _, item := range m.items {
		w := runewidth.StringWidth(item.Label)
		if w > max {
			max = w
		}
		sub := item.Subtitle
		if sub == "" {
			sub = m.input.DistroLabel
		}
		if sw := runewidth.StringWidth(sub); sw > max {
			max = sw
		}
	}
	if max > 28 {
		max = 28
	}
	return max + 4
}

func (m presetModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.cardW = m.computeCardWidth()
		return m, nil
	case tea.KeyMsg:
		cols := m.gridCols()
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "left", "h":
			if m.cursor > 0 {
				m.cursor--
			}
			return m, nil
		case "right", "l", "tab":
			if m.cursor < m.itemCount()-1 {
				m.cursor++
			}
			return m, nil
		case "shift+tab":
			if m.cursor > 0 {
				m.cursor--
			}
			return m, nil
		case "up", "k":
			if m.cursor-cols >= 0 {
				m.cursor -= cols
			}
			return m, nil
		case "down", "j":
			if m.cursor+cols <= m.itemCount()-1 {
				m.cursor += cols
			}
			return m, nil
		case "enter":
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m presetModel) View() string {
	if m.itemCount() == 0 {
		return "No presets available.\n"
	}

	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Render("os-configs")
	subTitle := lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).Render("Post-install setup")
	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("86")).Render("Choose a preset")
	hint := lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).Render("← → ↑ ↓ move · Tab select · Enter confirm · q quit")

	grid := m.renderGrid()
	gridBlock := lipgloss.Place(m.width, lipgloss.Height(grid), lipgloss.Center, lipgloss.Center, grid)

	body := lipgloss.JoinVertical(lipgloss.Center, title, subTitle, "", header, "", gridBlock)

	contentH := lipgloss.Height(body) + lipgloss.Height(hint) + 2
	topPad := (m.height - contentH) / 2
	if topPad < 0 {
		topPad = 0
	}

	main := lipgloss.JoinVertical(lipgloss.Center, body, "", hint)
	return lipgloss.NewStyle().
		Width(m.width).
		Height(m.height).
		Padding(topPad, 0, 1, 0).
		Render(main)
}

func runPresetPicker(inputPath, outputPath string) error {
	in, err := loadPresetInput(inputPath)
	if err != nil {
		return err
	}

	items := append([]presetOption{}, in.Presets...)
	if in.Custom.ID != "" {
		items = append(items, in.Custom)
	} else {
		items = append(items, presetOption{ID: "custom", Label: "Custom", Subtitle: "pick your apps"})
	}

	m := presetModel{
		input:  in,
		items:  items,
		cardW:  22,
		cursor: 0,
	}
	m.cardW = m.computeCardWidth()

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}

	fm := final.(presetModel)
	if fm.quitting && !fm.done {
		os.Exit(1)
	}

	out := presetOutput{Choice: fm.items[fm.cursor].ID}
	dest, err := openOutput(outputPath)
	if err != nil {
		return err
	}
	defer dest.Close()

	enc := json.NewEncoder(dest)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}

func openOutput(path string) (*os.File, error) {
	if path != "" {
		return os.Create(path)
	}
	return os.Stdout, nil
}
