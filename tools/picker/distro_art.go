package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

// Compact ASCII marks (display-only). Each distro uses equal-width lines.
var distroArtLines = map[string][]string{
	"ubuntu": {
		"┌─────┐",
		"│  ●  │",
		"└─────┘",
	},
	"debian": {
		" ,---.",
		"( sw )",
		" `---'",
	},
	"fedora": {
		" /\\_/\\",
		"( o.o )",
		" > ^ <",
	},
	"arch": {
		"  /\\",
		" /  \\",
		"/____\\",
	},
	"linuxmint": {
		" leaf ",
		" /\\_/\\",
		"(mint)",
	},
	"pop": {
		"[POP!]",
		" ┌─┐ ",
		" └─┘ ",
	},
	"pop-os": {
		"[POP!]",
		" ┌─┐ ",
		" └─┘ ",
	},
	"zorin": {
		" ZOR ",
		"┌───┐",
		"└───┘",
	},
	"endeavouros": {
		" >> ",
		"/  \\",
		"EOS ",
	},
	"manjaro": {
		" /M\\",
		"/   \\",
		"     ",
	},
	"garuda": {
		"\\|/",
		"/|\\",
		"GDR",
	},
	"neon": {
		"KDE",
		"neo",
		"n  ",
	},
	"elementary": {
		" e ",
		"┌─┐",
		"└─┘",
	},
	"kali": {
		"/\\_/\\",
		"kali",
		"\\___/",
	},
}

func distroArt(distroID string) []string {
	id := strings.ToLower(strings.TrimSpace(distroID))
	if art, ok := distroArtLines[id]; ok {
		return normalizeArtLines(art)
	}
	return normalizeArtLines([]string{
		"Linux",
		" os ",
		"cfg",
	})
}

func normalizeArtLines(lines []string) []string {
	maxW := 0
	for _, line := range lines {
		if w := runewidth.StringWidth(line); w > maxW {
			maxW = w
		}
	}
	out := make([]string, len(lines))
	for i, line := range lines {
		out[i] = padRunewidth(line, maxW)
	}
	return out
}

func padRunewidth(s string, width int) string {
	w := runewidth.StringWidth(s)
	if w >= width {
		return s
	}
	return s + strings.Repeat(" ", width-w)
}

func renderArtBlock(color lipgloss.Color, lines []string) string {
	style := lipgloss.NewStyle().Foreground(color).Bold(true)
	normalized := normalizeArtLines(lines)
	var rows []string
	for _, line := range normalized {
		rows = append(rows, style.Render(line))
	}
	return lipgloss.JoinVertical(lipgloss.Left, rows...)
}
