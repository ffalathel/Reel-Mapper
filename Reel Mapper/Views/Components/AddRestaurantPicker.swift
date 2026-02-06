import SwiftUI

struct AddRestaurantPicker: View {
    let currentList: UserList
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if homeViewModel.unsortedRestaurants.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Text("No unsorted restaurants")
                            .font(.headline)
                        Text("All your restaurants are already sorted!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else {
                    Section(header: Text("Unsorted Restaurants")) {
                        ForEach(homeViewModel.unsortedRestaurants) { restaurant in
                            Button(action: {
                                Task {
                                    await homeViewModel.moveRestaurant(restaurant, to: currentList)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(restaurant.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text(restaurant.city)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to \(currentList.name)")
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
