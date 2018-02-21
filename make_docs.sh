#!/bin/bash

jazzy --clean --author "palle-k" --author_url https://github.com/palle-k --github_url https://github.com/palle-k/Covfefe --output docs/ --theme fullwidth --documentation BNF.md
rm -rf build
