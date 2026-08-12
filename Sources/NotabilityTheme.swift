import SwiftUI
import AppKit

struct NotabilityTheme {
    // Colors inspired by Notability's clean canvas & vibrant UI
    static let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let successGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warningOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    
    // Layout parameters
    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
}

// Reusable Notability Card Container Component
struct NotabilityCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(NotabilityTheme.cardPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: NotabilityTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NotabilityTheme.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// Custom Pill Button for Source Selection
struct MethodButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? NotabilityTheme.accentBlue : Color.primary.opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}