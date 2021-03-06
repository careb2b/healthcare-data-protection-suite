// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Generates markdown files for Terraform engine recipes.
// Meant to be run from the repo root like so:
// go run ./scripts/generate_schema_docs

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/GoogleCloudPlatform/healthcare-data-protection-suite/internal/hcl"
)

var (
	recipesDir = flag.String("recipes_dir", "templates/tfengine/recipes", "Directory hosting Terraform engine recipes.")
	outputDir  = flag.String("output_dir", "docs/tfengine/recipes", "Directory to output markdown files.")
)

var schemaRE = regexp.MustCompile(`(?s)(?:schema = {)(.+?)(?:}\n\n)`)

func main() {
	if err := run(*recipesDir, *outputDir); err != nil {
		log.Fatal(err)
	}
}

func run(recipesDir, outputDir string) error {
	tmp, err := ioutil.TempDir("", "")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	fn := func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		matches, err := findMatches(path)
		if err != nil {
			return err
		}
		if len(matches) == 0 {
			return nil
		}

		s, err := schemaFromHCL(matches[1])
		if err != nil {
			return err
		}

		buf := new(bytes.Buffer)
		if err := tmpl.Execute(buf, s); err != nil {
			return err
		}

		outPath := filepath.Join(outputDir, strings.Replace(info.Name(), ".hcl", ".md", 1))
		if err := ioutil.WriteFile(outPath, buf.Bytes(), 0755); err != nil {
			return fmt.Errorf("write %q: %v", outPath, err)
		}

		return nil
	}
	if err := filepath.Walk(recipesDir, fn); err != nil {
		return err
	}
	return nil
}

// findMatches extracts the schema from an HCL recipe.
// Matches will be empty if there is no schema or the file is not HCL.
func findMatches(path string) ([][]byte, error) {
	if filepath.Ext(path) != ".hcl" {
		return nil, nil
	}

	b, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}

	matches := schemaRE.FindSubmatch(b)
	if l := len(matches); l != 0 && l != 2 {
		return nil, fmt.Errorf("unexpected number of matches: got %q, want 0 or 2", len(matches))
	}
	return matches, nil
}

func schemaFromHCL(b []byte) (*schema, error) {
	sj, err := hcl.ToJSON(b)
	if err != nil {
		return nil, err
	}

	s := new(schema)
	if err := json.Unmarshal(sj, s); err != nil {
		return nil, err
	}
	massageSchema(s)
	return s, nil
}

// massageSchema prepares the schema for templating.
func massageSchema(s *schema) {
	props := s.Properties
	s.Properties = make(map[string]*property, len(props))
	flattenObjects(s, props, "")

	for _, prop := range s.Properties {
		prop.Description = strings.TrimSpace(lstrip(prop.Description))
	}
}

// flattenObjects will add the properties of all objects to the top level schema.
func flattenObjects(s *schema, props map[string]*property, prefix string) {
	for name, prop := range props {
		name = prefix + name
		s.Properties[name] = prop
		switch prop.Type {
		case "object":
			flattenObjects(s, prop.Properties, name+".")
		case "array":
			prop.Type = fmt.Sprintf("array(%s)", prop.Items.Type)
			flattenObjects(s, prop.Items.Properties, name+".")
		}
	}
}

// lstrip trims left space from all lines.
func lstrip(s string) string {
	var b strings.Builder
	for _, line := range strings.Split(s, "\n") {
		b.WriteString(strings.TrimLeft(line, " "))
		b.WriteRune('\n')
	}
	return b.String()
}
