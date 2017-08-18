#!/bin/bash
sourcekitten doc --spm-module Covfefe > docs.json

jazzy --clean --author "palle-k" --author_url https://github.com/palle-k --github_url https://github.com/palle-k/Covfefe --output docs/ --theme fullwidth --sourcekitten-sourcefile docs.json
rm docs.json
rm -rf build
