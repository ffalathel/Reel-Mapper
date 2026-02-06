import SwiftUI

struct AddToFolderSheet: View {
    let restaurant: Restaurant
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if homeViewModel.lists.isEmpty {
                    Text("No folders created yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(homeViewModel.lists) { list in
                        Button(action: {
                            Task {
                                await homeViewModel.moveRestaurant(restaurant, to: list)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                Text(list.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Add to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
