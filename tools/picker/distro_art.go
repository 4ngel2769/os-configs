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

// ufetch-style multiline ASCII distro art.
var distroArtLines = map[string][]string{
	"ubuntu": {
		"       _",
		"   ---(_)",
		"_/  ---  \\",
		"(_) |   |",
		"  \\  --- _/",
		"     ---(_)",
	},
	"debian": {
		"  ,---._",
		" /`  __  \\",
		"|   /    |",
		"|   `.__.`",
		" \\",
		"  `-,_",
	},
	"arch": {
		"      /\\",
		"     /  \\",
		"    /\\   \\",
		"   /  __  \\",
		"  /  (  )  \\",
		" / __|  |__\\\\",
		"/.`        `.",
	},
	"fedora": {
		"      _____",
		"     /   __)",
		"     |  /  \\ \\",
		"  ___|  |__/ /",
		" / (_    _)_/",
		"/ /  |  |",
		"\\ \\__/  |",
		" \\(_____/",
	},
	"manjaro": {
		"||||||||| ||||",
		"||||||||| ||||",
		"||||      ||||",
		"|||| |||| ||||",
		"|||| |||| ||||",
		"|||| |||| ||||",
		"|||| |||| ||||",
	},
	"void": {
		"    _______",
		"    \\_____ `-",
		" /\\   ___ `- \\",
		"| |  /   \\  | |",
		"| |  \\___/  | |",
		" \\ \\`-_____  \\/",
		"  `-______\\",
	},
	"alpine": {
		"      /\\",
		"     /  \\",
		"    / /\\ \\  /\\",
		"   / /  \\ \\/  \\",
		"  / /    \\ \\/\\ \\",
		" / / /|   \\ \\ \\ \\",
		"/_/ /_|    \\_\\ \\_\\",
	},
	"linuxmint": {
		"  _____________",
		" |_   ___   ___|",
		"   | |   | |",
		"   | |   | |",
		"  _| |___| |_",
		" |___________|",
	},
	"mint": {
		"  _____________",
		" |_   ___   ___|",
		"   | |   | |",
		"   | |   | |",
		"  _| |___| |_",
		" |___________|",
	},
	"pop": {
		"______   ______",
		"| ___ \\ /  __  \\",
		"| |_/ / | |  | |",
		"|  __/  | |  | |",
		"| |     | |__| |",
		"\\_|      \\____/",
	},
	"pop-os": {
		"______   ______",
		"| ___ \\ /  __  \\",
		"| |_/ / | |  | |",
		"|  __/  | |  | |",
		"| |     | |__| |",
		"\\_|      \\____/",
	},
	"zorin": {
		"/-------\\",
		"|  ___  |",
		"| /   \\ |",
		"| \\___/ |",
		"|_______|",
		"\\-------/",
	},
	"endeavouros": {
		"      /\\",
		"     /  \\",
		"    /    \\",
		"   /  /\\  \\",
		"  /  /  \\  \\",
		" /__/    \\__\\",
	},
	"garuda": {
		"   /\\",
		"  /  \\",
		" / /\\ \\",
		"/ /  \\ \\",
		"\\ \\__/ /",
		" \\____/",
	},
	"neon": {
		"  /\\",
		" /  \\",
		"/ /\\ \\",
		"\\ \\/ /",
		" \\__/",
	},
	"elementary": {
		"  _______",
		" /  ___  \\",
		"|  /   \\  |",
		"|  \\___/  |",
		" \\_______/",
	},
	"kali": {
		"  /\\_/\\",
		" ( o.o )",
		"  > ^ <",
		" /|   |\\",
		"(_|   |_)",
	},
}

func distroArt(distroID string) []string {
	id := strings.ToLower(strings.TrimSpace(distroID))
	if art, ok := distroArtLines[id]; ok {
		return normalizeArtLines(art)
	}
	// Generic fallback motif
	return normalizeArtLines([]string{
		"  .---.",
		" /  _  \\",
		" | ( ) |",
		" \\  _  /",
		"  `---'",
	})
}
