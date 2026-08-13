package main

import (
	"encoding/json"
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type menuItem struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Subtitle string `json:"subtitle,omitempty"`
}

type menuInput struct {
	Banner     bannerInfo `json:"banner"`
	Mode       string     `json:"mode"`
	Title      string     `json:"title"`
	Subtitle   string     `json:"subtitle,omitempty"`
	Body       string     `json:"body,omitempty"`
	Message    string     `json:"message,omitempty"`
	DefaultYes bool       `json:"default_yes"`
	Items      []menuItem `json:"items,omitempty"`
}

type menuOutput struct {
	Choice    string `json:"choice,omitempty"`
	Confirmed *bool  `json:"confirmed,omitempty"`
}

type menuModel struct {
	in         menuInput
	cursor     int
	confirmYes bool
	width      int
	height     int
	quitting   bool
	done       bool
}

func (m menuModel) Init() tea.Cmd { return nil }

func (m menuModel) filteredItems() []menuItem {
	return m.in.Items
}

func (m *menuModel) moveCursor(delta int) {
	items := m.filteredItems()
	if len(items) == 0 {
		return
	}
	m.cursor += delta
	if m.cursor < 0 {
		m.cursor = len(items) - 1
	}
	if m.cursor >= len(items) {
		m.cursor = 0
	}
}

func (m menuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		switch m.in.Mode {
		case "confirm":
			switch msg.String() {
			case "ctrl+c", "q", "esc":
				m.quitting = true
				return m, tea.Quit
			case "left", "h", "y":
				m.confirmYes = true
			case "right", "l", "n":
				m.confirmYes = false
			case "tab":
				m.confirmYes = !m.confirmYes
			case "enter":
				m.done = true
				return m, tea.Quit
			}
		case "info":
			switch msg.String() {
			case "ctrl+c", "q", "esc":
				m.quitting = true
				return m, tea.Quit
			case "enter":
				m.done = true
				return m, tea.Quit
			}
		default:
			switch msg.String() {
			case "ctrl+c", "q", "esc":
				m.quitting = true
				return m, tea.Quit
			case "up", "k":
				m.moveCursor(-1)
			case "down", "j":
				m.moveCursor(1)
			case "enter":
				if len(m.filteredItems()) > 0 {
					m.done = true
					return m, tea.Quit
				}
			}
		}
	}
	return m, nil
}

func (m menuModel) renderList() string {
	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("86")).Render(m.in.Title)
	sub := ""
	if m.in.Subtitle != "" {
		sub = lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("245")).Render(m.in.Subtitle)
	}

	listW := min(m.width-8, 72)
	var rows []string
	items := m.filteredItems()
	for i, item := range items {
		label := item.Label
		if item.Subtitle != "" {
			label = fmt.Sprintf("%s — %s", item.Label, item.Subtitle)
		}
		label = truncateRunes(label, listW-4)
		var line string
		if i == m.cursor {
			line = "▸ " + lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("229")).Render(label)
		} else {
			line = "  " + lipgloss.NewStyle().Foreground(lipgloss.Color("245")).Render(label)
		}
		rows = append(rows, lipgloss.NewStyle().Width(listW).Render(line))
	}

	list := lipgloss.JoinVertical(lipgloss.Left, rows...)
	block := lipgloss.JoinVertical(lipgloss.Center, header, sub, "", list)
	return lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(block)
}

func (m menuModel) renderConfirm() string {
	title := m.in.Title
	if title == "" {
		title = "Confirm"
	}
	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("86")).Render(title)

	body := ""
	if m.in.Body != "" {
		body = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("240")).
			Padding(1, 2).
			Width(min(m.width-10, 76)).
			Align(lipgloss.Left).
			Foreground(lipgloss.Color("252")).
			Render(m.in.Body)
	}

	msgW := min(m.width-8, 76)
	msg := lipgloss.NewStyle().
		Align(lipgloss.Center).
		Width(msgW).
		Foreground(lipgloss.Color("252")).
		Margin(1, 0).
		Render(m.in.Message)

	gap := lipgloss.NewStyle().Width(3).Render("")
	yesStyle := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(0, 2).Foreground(lipgloss.Color("10"))
	noStyle := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(0, 2).Foreground(lipgloss.Color("117"))

	if m.confirmYes {
		yesStyle = yesStyle.Bold(true).BorderForeground(lipgloss.Color("10"))
		noStyle = noStyle.BorderForeground(lipgloss.Color("240"))
	} else {
		noStyle = noStyle.Bold(true).BorderForeground(lipgloss.Color("117"))
		yesStyle = yesStyle.BorderForeground(lipgloss.Color("240"))
	}

	buttons := lipgloss.JoinHorizontal(lipgloss.Top, yesStyle.Render("Yes"), gap, noStyle.Render("No"))
	buttons = lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Margin(1, 0).Render(buttons)

	parts := []string{header}
	if body != "" {
		parts = append(parts, "", lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(body))
	}
	parts = append(parts, lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(msg), buttons)
	return lipgloss.JoinVertical(lipgloss.Center, parts...)
}

func (m menuModel) renderInfo() string {
	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Foreground(lipgloss.Color("86")).Render(m.in.Title)

	body := ""
	if m.in.Body != "" {
		body = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("86")).
			Padding(1, 2).
			Width(min(m.width-10, 76)).
			Align(lipgloss.Left).
			Foreground(lipgloss.Color("252")).
			Render(m.in.Body)
	}

	btn := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("10")).
		Bold(true).
		Padding(0, 2).
		Foreground(lipgloss.Color("10")).
		Render("Continue")
	btn = lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Margin(1, 0).Render(btn)

	parts := []string{header}
	if body != "" {
		parts = append(parts, "", lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(body))
	}
	parts = append(parts, btn)
	return lipgloss.JoinVertical(lipgloss.Center, parts...)
}

func (m menuModel) View() string {
	w := m.width
	if w < 40 {
		w = 40
	}
	h := m.height
	if h < 16 {
		h = 16
	}

	banner := renderBanner(w, m.in.Banner)
	var body string
	var hint string

	switch m.in.Mode {
	case "confirm":
		body = m.renderConfirm()
		hint = lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("245")).
			Render("←/→ toggle · Enter submit · y Yes · n No")
	case "info":
		body = m.renderInfo()
		hint = lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("245")).
			Render("Enter continue")
	default:
		body = m.renderList()
		hint = lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(lipgloss.Color("245")).
			Render("↑↓ move · Enter select")
	}

	content := lipgloss.JoinVertical(lipgloss.Center, banner, "", body, "", hint)
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Top, content)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func runMenuPicker(inputPath, outputPath string) error {
	raw, err := os.ReadFile(inputPath)
	if err != nil {
		return err
	}
	var in menuInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return err
	}

	m := menuModel{
		in:         in,
		confirmYes: in.DefaultYes,
	}
	if in.Mode != "confirm" && len(in.Items) > 0 {
		m.cursor = 0
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}

	fm := final.(menuModel)
	if fm.quitting && !fm.done {
		os.Exit(1)
	}

	out := menuOutput{}
	switch in.Mode {
	case "confirm":
		v := fm.confirmYes
		out.Confirmed = &v
	case "info":
		// no payload
	default:
		items := fm.filteredItems()
		if fm.cursor >= 0 && fm.cursor < len(items) {
			out.Choice = items[fm.cursor].ID
		}
	}

	dest, err := openOutput(outputPath)
	if err != nil {
		return err
	}
	defer dest.Close()
	enc := json.NewEncoder(dest)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}
