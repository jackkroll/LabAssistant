//
//  CloudKitSyncPresentation.swift
//  LabAssistant
//

import CloudKitSyncMonitor
import SwiftUI

enum CloudKitSyncPresentation {
    static func summaryStatus(from syncMonitor: SyncMonitor) -> SyncMonitor.SyncSummaryStatus {
        if LabAssistantLaunchConfiguration.shouldSimulateCloudKitSyncedStatus {
            return .succeeded
        }
        return syncMonitor.syncStateSummary
    }
}
