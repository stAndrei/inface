# Proposal: bootstrap-mac-app

## Why

Нужен каркас macOS-приложения Inface: menu bar, настройки, permissions stub — база для EventKit и алертов.

## What Changes

- SPM-пакет с targets InfaceCore + InfaceApp
- MenuBarExtra с русским UI
- Окно настроек (заглушка)
- Info.plist usage strings для Calendar
- README со сборкой

## Non-goals

- EventKit sync, alerts, join links
- App Store / notarization

## Impact

- New repo layout under Package.swift
