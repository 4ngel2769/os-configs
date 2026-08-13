package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

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

func stripANSI(s string) string {
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

var distroArtLines = map[string][]string{
	"ubuntu": {
		" __ __ ",
		"|  __  |",
		"|_|  |_|",
	},
	"debian": {
		"  ____ ",
		" |    \\",
		" |____/",
	},
	"fedora": {
		"  ___  ",
		" / __\\ ",
		" \\___/ ",
	},
	"arch": {
		"  /\\  ",
		" /  \\ ",
		"/_/\\_\\",
	},
	"linuxmint": {
		" /\\_/\\",
		"( mint )",
		" \\___/ ",
	},
	"pop": {
		" _ __ ",
		"| POP |",
		"|_____|",
	},
	"pop-os": {
		" _ __ ",
		"| POP |",
		"|_____|",
	},
	"zorin": {
		" ____ ",
		"| Z  |",
		"|____|",
	},
	"endeavouros": {
		"  >>  ",
		" /  \\ ",
		"/_/\\_\\",
	},
	"manjaro": {
		" /M\\ ",
		"/   \\",
		"     ",
	},
	"garuda": {
		" \\|/ ",
		"-O- ",
		"/|\\ ",
	},
	"neon": {
		" KDE ",
		" neo ",
		" n  ",
	},
	"elementary": {
		"  e  ",
		" /\\ ",
		" \\/ ",
	},
	"kali": {
		" /\\_/\\",
		"( kali )",
		" \\_/_/",
	},
}

func distroArt(distroID string) []string {
	id := strings.ToLower(strings.TrimSpace(distroID))
	if art, ok := distroArtLines[id]; ok {
		return normalizeArtLines(art)
	}
	// Generic tool/wrench motif for unknown distros.
	return normalizeArtLines([]string{
		" .---.",
		" | O |",
		" `-+-'",
	})
}
