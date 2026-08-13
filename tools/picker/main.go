package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	catalogPath := flag.String("catalog", "", "software picker catalog JSON")
	presetsPath := flag.String("presets", "", "preset picker input JSON")
	menuPath := flag.String("menu", "", "menu picker input JSON")
	outputPath := flag.String("output", "", "write result JSON to file (recommended)")
	tuiPath := flag.String("tui", "", "TUI strings and theme JSON (default: compiled defaults)")
	flag.Parse()

	if err := loadTUI(*tuiPath); err != nil {
		fmt.Fprintf(os.Stderr, "picker: load tui config: %v\n", err)
		os.Exit(1)
	}

	switch {
	case *presetsPath != "":
		if err := runPresetPicker(*presetsPath, *outputPath); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case *catalogPath != "":
		if err := runSoftwarePicker(*catalogPath, *outputPath); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case *menuPath != "":
		if err := runMenuPicker(*menuPath, *outputPath); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	default:
		fmt.Fprintln(os.Stderr, "usage: os-configs-picker --catalog FILE | --presets FILE | --menu FILE [--output FILE] [--tui FILE]")
		os.Exit(2)
	}
}
