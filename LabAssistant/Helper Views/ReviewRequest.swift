//
//  ReviewRequest.swift
//  LabAssistant
//
//  Created by Jack Kroll on 6/20/26.
//

import SwiftUI
import StoreKit

struct ReviewRequest: View {
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var promotionBannerManager: PromotionBannerManager

    var body: some View {
            VStack {
                HStack {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                Text("Enjoying Lab Assistant?")
                    .font(.title3)
                    .bold()
                HStack {
                    Button {
                        promotionBannerManager.handleReviewAccepted()
                        requestReview()
                    } label: {
                        Text("Yes")
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                    
                    Button {
                        promotionBannerManager.handleReviewDeclined()
                    } label: {
                        Text("No")
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                }
                Text("Leaving a review helps others discover Lab Assistant")
                    .font(.caption2)
            }
            .padding()
            .overlay(alignment: .topTrailing) {
                Menu {
                    Button("Close") {
                        promotionBannerManager.dismissBanner(.review, action: .close)
                    }
                    Button("Show less often") {
                        promotionBannerManager.dismissBanner(.review, action: .showLessOften)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .background(.blue.gradient)
            .glassEffect(in: ConcentricRectangle(corners: .concentric(minimum: 32), isUniform: true))
            .foregroundStyle(.white)
            .clipShape(ConcentricRectangle(corners: .concentric(minimum: 32), isUniform: true))
            .padding()
        }
}

struct ProBanner: View {
    @EnvironmentObject private var promotionBannerManager: PromotionBannerManager

    var body: some View {
        NavigationLink {
            UpsellView(context: .presets)
        } label : {
            VStack {
                Text("Explore Lab Assistant Pro")
                    .font(.title3)
                    .bold()
                HStack {
                    Text("Unlock unlimited workflows and new tools to speed up your setup")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Close") {
                    promotionBannerManager.dismissBanner(.pro, action: .close)
                }
                Button("Show less often") {
                    promotionBannerManager.dismissBanner(.pro, action: .showLessOften)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .background(.red.gradient)
        .glassEffect(in: ConcentricRectangle(corners: .concentric(minimum: 32), isUniform: true))
        .foregroundStyle(.white)
        .clipShape(ConcentricRectangle(corners: .concentric(minimum: 32), isUniform: true))
        .padding()
    }
}

#Preview("Banner appearance") {
    NavigationStack {
        VStack  {
            ReviewRequest()
            ProBanner()
            Spacer()
        }
    }
    .environmentObject(PromotionBannerManager())
}
