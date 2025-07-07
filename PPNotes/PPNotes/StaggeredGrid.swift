//
//  AdaptiveGrid.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI

struct AdaptiveGrid<Content: View, T: Identifiable>: View {
    let items: [T]
    let spacing: CGFloat
    let screenWidth: CGFloat
    let content: (T, Int) -> Content
    
    init(
        items: [T],
        spacing: CGFloat = 16,
        screenWidth: CGFloat,
        @ViewBuilder content: @escaping (T, Int) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.screenWidth = screenWidth
        self.content = content
    }
    
    // Calculate optimal number of columns based on screen width
    private var columns: Int {
        if screenWidth < 600 {
            return 2  // iPhone
        } else if screenWidth < 900 {
            return 3  // iPad Portrait / Small iPad
        } else if screenWidth < 1200 {
            return 4  // iPad Landscape / Medium iPad
        } else {
            return 5  // Large iPad / Desktop
        }
    }
    
    // Calculate card width based on available space
    private var cardWidth: CGFloat {
        let totalSpacing = spacing * CGFloat(columns + 1)
        let availableWidth = screenWidth - totalSpacing
        return availableWidth / CGFloat(columns)
    }
    
    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { rowIndex in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { columnIndex in
                        let itemIndex = rowIndex + columnIndex
                        if itemIndex < items.count {
                            content(items[itemIndex], itemIndex)
                                .frame(maxWidth: .infinity)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, spacing)
    }
}

// Keep the old StaggeredGrid for backward compatibility
struct StaggeredGrid<Content: View, T: Identifiable>: View {
    let items: [T]
    let spacing: CGFloat
    let columns: Int
    let content: (T, Int) -> Content
    
    init(
        items: [T],
        spacing: CGFloat = 16,
        columns: Int = 2,
        @ViewBuilder content: @escaping (T, Int) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.columns = columns
        self.content = content
    }
    
    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { rowIndex in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { columnIndex in
                        let itemIndex = rowIndex + columnIndex
                        if itemIndex < items.count {
                            content(items[itemIndex], itemIndex)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, spacing)
    }
}

struct PreviewItem: Identifiable {
    let id = UUID()
    let value: Int
}

#Preview {
    GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 20) {
                Text("Adaptive Grid (width: \(Int(geometry.size.width)))")
                    .font(.headline)
                
                AdaptiveGrid(
                    items: (0..<15).map { PreviewItem(value: $0) },
                    spacing: 16,
                    screenWidth: geometry.size.width
                ) { item, index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 120 + CGFloat(index % 4) * 20)
                        .overlay(
                            Text("\(item.value)")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
                
                Divider()
                
                Text("Original Staggered Grid")
                    .font(.headline)
                
                StaggeredGrid(
                    items: (0..<10).map { PreviewItem(value: $0) },
                    spacing: 16,
                    columns: 2
                ) { item, index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 150 + CGFloat(index % 3) * 20, height: 120 + CGFloat(index % 4) * 20)
                        .overlay(
                            Text("\(item.value)")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
            }
        }
    }
} 