import SwiftUI

struct ListDetailView: View {
    let list: UserList
    @StateObject private var viewModel: ListDetailViewModel
    
    init(list: UserList) {
        self.list = list
        _viewModel = StateObject(wrappedValue: ListDetailViewModel(list: list))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.restaurants.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No restaurants in this list yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add restaurants from your unsorted list")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(viewModel.restaurants) { restaurant in
                        NavigationLink(value: restaurant) {
                            RestaurantCardView(restaurant: restaurant)
                                .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.removeRestaurant(restaurant)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.removeRestaurant(restaurant)
                                }
                            } label: {
                                Label("Delete Restaurant", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.fetchRestaurants()
        }
    }
}
