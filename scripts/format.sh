#!/usr/bin/env bash
# Formats all Swift sources in place.
set -euo pipefail
cd "$(dirname "$0")/.."
swift format format --in-place --recursive --parallel Trag TragTests TragKit/Sources TragKit/Tests TragKit/Package.swift
