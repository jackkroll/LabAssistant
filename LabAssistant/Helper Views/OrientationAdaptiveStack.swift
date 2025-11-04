//
//  OrientationAdaptiveStack.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/25/25.
//


import SwiftUI

struct OrientationAdaptiveStack<Content: View>: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let spacing: CGFloat?
    let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: spacing, content: content)
            } else {
                VStack(spacing: spacing, content: content)
            }
        }
        .animation(.default, value: verticalSizeClass)
    }
}
