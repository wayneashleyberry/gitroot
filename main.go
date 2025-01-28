package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/urfave/cli/v3"
)

func main() {
	cmd := &cli.Command{
		Name:  "gitroot",
		Usage: "Find and move to your git root directory",
		Commands: []*cli.Command{
			{
				Name:    "find",
				Aliases: []string{"a"},
				Usage:   "Find the root .git directory",
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:        "match",
						Value:       "last",
						Usage:       "Use the first or last .git directory found",
						DefaultText: "last",
						Validator: func(s string) error {
							if s != "first" && s != "last" {
								return errors.New("expected 'first' or 'last'")
							}

							return nil
						},
					},
				},
				Action: func(ctx context.Context, cmd *cli.Command) error {
					match := cmd.String("match")

					cwd, err := os.Getwd()
					if err != nil {
						return err
					}

					if match == "first" {
						fmt.Println(FindGitDir(cwd, true))
					}

					fmt.Println(FindGitDir(cwd, false))

					return nil
				},
			},
			{
				Name:    "init",
				Aliases: []string{"t"},
				Usage:   "Initialise your shell",
				Commands: []*cli.Command{
					{
						Name: "fish",
						Action: func(ctx context.Context, cmd *cli.Command) error {
							fmt.Println(`alias gr "cd (gitroot find --match last)"`)

							return nil
						},
					},
					{
						Name: "bash",
						Action: func(ctx context.Context, cmd *cli.Command) error {
							return errors.New("not yet implemented")
						},
					},
					{
						Name: "zsh",
						Action: func(ctx context.Context, cmd *cli.Command) error {
							return errors.New("not yet implemented")
						},
					},
				},
			},
		},
	}

	if err := cmd.Run(context.Background(), os.Args); err != nil {
		log.Fatal(err)
	}
}

// FindGitDir recursively searches for a .git directory.
// If `findFirst` is true, it returns the first matching directory found.
// Otherwise, it returns the last matching directory found.
// If no .git directory is found, it returns the current working directory.
func FindGitDir(startDir string, findFirst bool) string {
	var match string
	var search func(string)

	search = func(dir string) {
		if match != "" && findFirst {
			return
		}

		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}

		for _, entry := range entries {
			if entry.IsDir() && entry.Name() == ".git" {
				match = dir
				if findFirst {
					return
				}
			}
		}

		parentDir := filepath.Dir(dir)
		if parentDir != dir {
			search(parentDir)
		}
	}

	search(startDir)

	if match == "" {
		return startDir
	}

	return match
}
