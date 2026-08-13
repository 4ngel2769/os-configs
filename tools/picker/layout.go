package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type bannerInfo struct {
	DistroID      string `json:"distro_id"`
	DistroLabel   string `json:"distro_label"`
	DistroColor   string `json:"distro_color"`
	MachineArch   string `json:"machine_arch"`
	PlatformLabel string `json:"platform_label"`
	GPULabel      string `json:"gpu_label,omitempty"`
	ShowGPU       bool   `json:"show_gpu"`
}

func renderBanner(width int, b bannerInfo) string {
	if width < 40 {
		width = 40
	}

	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(width).Render("os-configs")
	sub := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(lipgloss.Color("245")).
		Render("A post-install setup tool")
	div := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(lipgloss.Color("240")).
		Render(strings.Repeat("─", clamp(width-4, 20, 100)))

	badgeColor := lipgloss.Color("252")
	if b.DistroColor != "" {
		badgeColor = lipgloss.Color(b.DistroColor)
	}

	artBlock := renderArtBlock(badgeColor, distroArt(b.DistroID))

	arch := strings.TrimSpace(b.MachineArch)
	distroLine := b.DistroLabel
	if arch != "" {
		distroLine = fmt.Sprintf("%s %s", b.DistroLabel, arch)
	}

	infoStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	var infoLines []string
	infoLines = append(infoLines, infoStyle.Render("Detected Distribution: "+distroLine))
	infoLines = append(infoLines, infoStyle.Render("Platform: "+b.PlatformLabel))
	if b.ShowGPU && b.GPULabel != "" {
		infoLines = append(infoLines, infoStyle.Render("GPU: "+b.GPULabel))
	}
	infoBlock := lipgloss.JoinVertical(lipgloss.Left, infoLines...)

	gap := lipgloss.NewStyle().Width(3).Render("")
	detection := lipgloss.JoinHorizontal(lipgloss.Top, artBlock, gap, infoBlock)
	detection = lipgloss.NewStyle().Width(width).Align(lipgloss.Center).Render(detection)

	return lipgloss.JoinVertical(lipgloss.Center, title, sub, div, detection, div)
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
