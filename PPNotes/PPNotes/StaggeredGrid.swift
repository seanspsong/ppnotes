//
//  StaggeredGrid.swift
//  PPNotes
//
//  Created by Sean Song on 6/28/25.
//

import SwiftUI

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
    StaggeredGrid(
        items: (0..<10).map { PreviewItem(value: $0) },
        spacing: 16,
        columns: 2
    ) { item, index in
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.3))
            .frame(width: 150 + CGFloat(index % 3) * 20, height: 120 + CGFloat(index % 4) * 20)
            .overlay(
                Text("\(item.value)")
                    .font(.title)
                    .foregroundColor(.white)
            )
    }
} 