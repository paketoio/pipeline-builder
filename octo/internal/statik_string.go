/*
 * Copyright 2018-2020 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package internal

import (
	"io/ioutil"

	"github.com/rakyll/statik/fs"

	_ "github.com/paketo-buildpacks/pipeline-builder/octo/statik"
)

var statik, _ = fs.New()

func StatikString(path string) string {
	in, err := statik.Open(path)
	if err != nil {
		panic(err)
	}
	defer in.Close()

	b, err := ioutil.ReadAll(in)
	if err != nil {
		panic(err)
	}

	return string(b)
}
