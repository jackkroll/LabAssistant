//
//  CloudKitSyncStatusSheet.swift
//  LabAssistant
//
//  Created by Jack Kroll on 11/8/25.
//

import SwiftUI
import CloudKitSyncMonitor

struct CloudKitSyncStatusSheet: View {
    @StateObject private var syncMonitor = SyncMonitor.default
    var body: some View {
        VStack {
            Text("iCloud Sync Status")
                .font(.largeTitle)
                .fontWeight(.bold)
            ScrollView {
                GroupBox("Setup") {
                    Text(stateText(for: syncMonitor.setupState))
                    if syncMonitor.setupError != nil {
                        GroupBox("Error") {
                            Text(syncMonitor.setupError!.localizedDescription)
                        }
                    }
                }
                GroupBox("Import Data") {
                    Text(stateText(for: syncMonitor.setupState))
                    if syncMonitor.importError != nil {
                        GroupBox("Error") {
                            Text(syncMonitor.importError!.localizedDescription)
                        }
                    }
                }
                
                GroupBox("Export Data") {
                    Text(stateText(for: syncMonitor.setupState))
                    if syncMonitor.exportError != nil {
                        GroupBox("Error") {
                            Text(syncMonitor.exportError!.localizedDescription)
                        }
                    }
                }
            }
            
        }
        .padding()
    }
}

fileprivate var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    return dateFormatter
}()

func stateText(for state: SyncMonitor.SyncState) -> String {
    switch state {
    case .notStarted:
        return "Not started"
    case .inProgress(started: let date):
        return "In progress since \(dateFormatter.string(from: date))"
    case let .succeeded(started: _, ended: endDate):
        return "Succeeded at \(dateFormatter.string(from: endDate))"
    case let .failed(started: _, ended: endDate, error: _):
        return "Failed at \(dateFormatter.string(from: endDate))"
    }
}

#Preview {
    CloudKitSyncStatusSheet()
}
