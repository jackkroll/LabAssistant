//
//  ReviewRequest.swift
//  LabAssistant
//
//  Created by Jack Kroll on 6/20/26.
//

import SwiftUI
import StoreKit

struct ReviewRequest: View {
    @Environment(\.requestReview) var requestReview
    var body: some View {
            VStack {
                HStack {
                    ForEach(0..<5) { num in
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
                        requestReview()
                    } label: {
                        Text("Yes")
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                    
                    Button {
                        
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
                        
                    }
                    Button("Silence for a while") {
                        
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
                }
            }
        }
        .padding()
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Close") {
                    
                }
                Button("Silence for a while") {
                    
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
        }
        //.frame(maxWidth: .infinity)
        .background(.red.gradient)
        .glassEffect(in: ConcentricRectangle(corners: .concentric(minimum: 32), isUniform: true))
        .foregroundStyle(.white)
        .clipShape(ConcentricRectangle(corners: .concentric(minimum: 32), isUniform: true))
        .padding()
    }
}

#Preview {
    NavigationStack {
        VStack  {
            ReviewRequest()
            ProBanner()
            Spacer()
        }
    }
}
