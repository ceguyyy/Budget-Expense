# Gemini Context: Budget Expense

This file provides project-specific guidance for Gemini CLI when working on the Budget Expense Xcode project.

## Project Overview
Budget Expense is an iOS application built with SwiftUI. It includes features for tracking transactions, managing wallets, credit cards, debts, and uses CloudKit for data synchronization. It also integrates Vertex AI for OCR capabilities.

## Technical Stack
- **Language:** Swift
- **Framework:** SwiftUI
- **Data Persistence:** CloudKit, Core Data (implied by CloudKitManager)
- **AI Integration:** Vertex AI (VertexAIService.swift)
- **Authentication:** Apple Sign-In

## Documentation Reference
Refer to the following files for specific architectural and feature details:
- `ARCHITECTURE_DIAGRAM.md`: High-level system architecture.
- `MULTI_CURRENCY_DOCUMENTATION.md`: Logic for handling multiple currencies.
- `OCR_FIXES_GUIDE.md`: Guide for OCR-related implementations and fixes.

## Development Standards
- Follow standard SwiftUI and Swift concurrency patterns.
- Ensure all new UI components are responsive and follow the existing design system (see `ContentView.swift`, `DashboardView.swift`).
- When modifying data models, ensure CloudKit compatibility is maintained.
- Use `CurrencyManager.swift` for all currency-related calculations.

## Commands
- No specific shell commands are provided for this project yet. Use standard `xcodebuild` if necessary for CLI builds.
