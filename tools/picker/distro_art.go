package main

import "strings"

// Compact ASCII marks inspired by common distro logos (display-only, not official assets).
var distroArtLines = map[string][]string{
	"ubuntu": {
		"  ╭───╮  ",
		" ╭┤ ● ├╮ ",
		" │ ╰─╯ │ ",
		"  ╰───╯  ",
	},
	"debian": {
		"   ,--.   ",
		"  ( sw )  ",
		"   `--'   ",
	},
	"fedora": {
		"   /\\_/\\  ",
		"  ( o.o ) ",
		"   > ^ <  ",
	},
	"arch": {
		"    /\\    ",
		"   /  \\   ",
		"  /____\\  ",
	},
	"linuxmint": {
		"  (leaf)  ",
		"   /\\_/\\  ",
		"  ( mint )",
	},
	"pop": {
		"  [POP!]  ",
		"   ┌─┐   ",
		"   └─┘   ",
	},
	"pop-os": {
		"  [POP!]  ",
		"   ┌─┐   ",
		"   └─┘   ",
	},
	"zorin": {
		"   ZOR   ",
		"  ┌───┐  ",
		"  └───┘  ",
	},
	"endeavouros": {
		"   >>    ",
		"  /  \\   ",
		" Endeav  ",
	},
	"manjaro": {
		"   /M\\   ",
		"  /   \\  ",
		" /     \\ ",
	},
	"garuda": {
		"  \\|/   ",
		"  /|\\   ",
		" Garuda  ",
	},
	"neon": {
		"  (KDE)  ",
		"   neon   ",
	},
	"elementary": {
		"    e    ",
		"   ┌─┐   ",
		"   └─┘   ",
	},
	"kali": {
		"  /\\_/\\  ",
		" ( kali ) ",
		"  \\___/  ",
	},
}

func distroArt(distroID string) []string {
	id := strings.ToLower(strings.TrimSpace(distroID))
	if art, ok := distroArtLines[id]; ok {
		return art
	}
	return []string{
		"  Linux  ",
		"   os    ",
		" configs ",
	}
}
