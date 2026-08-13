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
		Render("Post-install setup")
	divWidth := clamp(width-4, 20, 100)
	div := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(lipgloss.Color("240")).
		Render(strings.Repeat("─", divWidth))

	badgeColor := lipgloss.Color("252")
	if b.DistroColor != "" {
		badgeColor = lipgloss.Color(b.DistroColor)
	}

	artBlock := renderArtBlock(badgeColor, distroArt(b.DistroID))

	arch := strings.TrimSpace(b.MachineArch)
	distroLine := b.DistroLabel
	if arch != "" {
		distroLine = fmt.Sprintf("%s · %s", b.DistroLabel, arch)
	}

	labelStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	valueStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("252")).Bold(true)

	var infoRows []string
	infoRows = append(infoRows, labelStyle.Render("Distribution")+valueStyle.Render("  "+distroLine))
	infoRows = append(infoRows, labelStyle.Render("Platform")+valueStyle.Render("     "+b.PlatformLabel))
	if b.ShowGPU && b.GPULabel != "" {
		infoRows = append(infoRows, labelStyle.Render("GPU")+valueStyle.Render("          "+b.GPULabel))
	}
	infoBlock := lipgloss.JoinVertical(lipgloss.Left, infoRows...)

	gap := lipgloss.NewStyle().Width(4).Render("")
	row := lipgloss.JoinHorizontal(lipgloss.Center, artBlock, gap, infoBlock)
	rowCentered := lipgloss.NewStyle().Width(width).Align(lipgloss.Center).Render(row)

	return lipgloss.JoinVertical(lipgloss.Top, title, sub, div, rowCentered, div)
}

// renderDetectionStrip is a one-line summary for dense layouts (software picker).
func renderDetectionStrip(width int, b bannerInfo) string {
	if width < 40 {
		width = 40
	}
	color := lipgloss.Color("252")
	if b.DistroColor != "" {
		color = lipgloss.Color(b.DistroColor)
	}
	parts := []string{
		lipgloss.NewStyle().Foreground(color).Bold(true).Render(b.DistroLabel),
		b.PlatformLabel,
	}
	if b.ShowGPU && b.GPULabel != "" {
		parts = append(parts, b.GPULabel)
	}
	line := strings.Join(parts, lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(" · "))
	return lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(lipgloss.Color("245")).Render(line)
}

func padLines(lines []string, count int) []string {
	out := make([]string, count)
	for i := 0; i < count; i++ {
		if i < len(lines) {
			out[i] = lines[i]
		} else {
			out[i] = ""
		}
	}
	return out
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
