//
//  CloudKitSyncStatusSheet.swift
//  LabAssistant
//
//  Created by Jack Kroll on 11/8/25.
//

import SwiftUI
import CloudKitSyncMonitor

struct CloudKitSyncStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncMonitor = SyncMonitor.default

    private var status: SyncMonitor.SyncSummaryStatus {
        CloudKitSyncPresentation.summaryStatus(from: syncMonitor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: status.symbolName)
                    .font(.system(size: 52))
                    .foregroundStyle(status.symbolColor)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                
                VStack(spacing: 8) {
                    Text(friendlyTitle(for: status))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(friendlyMessage(for: status))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                
                if let tip = friendlyTip(for: status) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.subheadline)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer(minLength: 0)
            }
            .padding(24)
            .presentationDetents([.medium])
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
    }

    private func friendlyTitle(for status: SyncMonitor.SyncSummaryStatus) -> String {
        switch status {
        case .succeeded:
            return "Up to Date"
        case .inProgress:
            return "Syncing…"
        case .notStarted:
            return "Getting Ready"
        case .noNetwork:
            return "You're Offline"
        case .accountNotAvailable:
            return "iCloud Isn't Available"
        case .error, .unknown:
            return "Sync Paused"
        case .notSyncing:
            return "Sync Paused"
        }
    }

    private func friendlyMessage(for status: SyncMonitor.SyncSummaryStatus) -> String {
        switch status {
        case .succeeded:
            return "Your workflows and chemicals are saved to iCloud and will appear on your other devices."
        case .inProgress:
            return "Your latest changes are being saved to iCloud."
        case .notStarted:
            return "iCloud sync is starting up. This usually only takes a moment."
        case .noNetwork:
            return "Your data is safe on this device. It will sync automatically when you're back online."
        case .accountNotAvailable:
            return "Sign in to iCloud to keep your workflows and chemicals in sync across your iPhone and iPad."
        case .error, .unknown:
            return "Something interrupted iCloud sync. Your data on this device is still saved."
        case .notSyncing:
            return "iCloud sync isn't running right now. Your data on this device is still saved."
        }
    }

    private func friendlyTip(for status: SyncMonitor.SyncSummaryStatus) -> String? {
        switch status {
        case .noNetwork:
            return "Connect to Wi‑Fi or cellular, then reopen this screen."
        case .accountNotAvailable:
            return "Open Settings, tap your name, then iCloud and make sure you're signed in."
        case .error, .unknown, .notSyncing:
            return "Try closing and reopening the app. If it continues, check Settings for any Apple ID prompts."
        case .succeeded, .inProgress, .notStarted:
            return nil
        }
    }
}

#Preview("Synced") {
    CloudKitSyncStatusSheet()
}
