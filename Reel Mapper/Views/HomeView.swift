import SwiftUI
import Clerk

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel.shared
    @State private var searchText = ""
    @State private var showMenu = false
    @State private var showAddSheet = false
    
    // Check if user has any content
    private var isEmpty: Bool {
        viewModel.lists.isEmpty && viewModel.unsortedRestaurants.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Custom Header
                    HStack {
                        Text("Reel Mapper")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button(action: { showAddSheet = true }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: { showMenu = true }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search your restaurants...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // EMPTY STATE or CONTENT
                    if isEmpty {
                        EmptyStateView(onAddTapped: { showAddSheet = true })
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        // Folders Section (Horizontal Scroll)
                        if !viewModel.lists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Folders")
                                        .font(.system(size: 18, weight: .bold))
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.lists) { list in
                                            NavigationLink(value: list) {
                                                ListCardView(list: list)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // All Saved Section (2-Column Grid)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("All Saved")
                                    .font(.system(size: 18, weight: .bold))
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            
                            if viewModel.unsortedRestaurants.isEmpty && !viewModel.isLoading {
                                Text("No restaurants yet. Share from Instagram to get started!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 32)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 16) {
                                    ForEach(viewModel.unsortedRestaurants) { restaurant in
                                        NavigationLink(value: restaurant) {
                                            RestaurantCardView(restaurant: restaurant)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                Task {
                                                    await viewModel.deleteRestaurant(restaurant)
                                                }
                                            } label: {
                                                Label("Delete Restaurant", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: UserList.self) { list in
                ListDetailView(list: list)
            }
            .navigationDestination(for: Restaurant.self) { restaurant in
                RestaurantDetailView(restaurant: restaurant)
            }
            .refreshable {
                await viewModel.fetchHome()
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
                // Only fetch if user is authenticated (checked from environment in parent)
                await viewModel.fetchHome()
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .sheet(isPresented: $showMenu) {
                MenuView()
            }
            .sheet(isPresented: $showAddSheet) {
                AddFromInstagramView()
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Menu View
struct MenuView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: AccountView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        Text("Account")
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: FoldersView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("Folders")
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: VisitedPlacesView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text("Visited Places")
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: FavoritesView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text("Favorites")
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: SettingsView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                        Text("Settings")
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Views
struct AccountView: View {
    @StateObject private var viewModel = HomeViewModel.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showEditProfile = false
    @State private var showAuthView = false
    @State private var isAuthenticated = false  // Set on appear from Clerk state
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Photo
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                        
                        Button(action: {}) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                    
                    VStack(spacing: 4) {
                        if isAuthenticated {
                            Text(userManager.currentUser?.name ?? "Welcome Back!")
                                .font(.system(size: 24, weight: .bold))
                            
                            Text(userManager.currentUser?.email ?? "Loading...")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Welcome")
                                .font(.system(size: 24, weight: .bold))
                            
                            Text("Sign in to get started")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isAuthenticated {
                        HStack(spacing: 12) {
                            Button(action: { showEditProfile = true }) {
                                Text("Edit Profile")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                            
                            Button(action: signOut) {
                                Text("Sign Out")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Button(action: { showAuthView = true }) {
                            Text("Sign In / Sign Up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 20)
                
                // Stats
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(viewModel.unsortedRestaurants.count)")
                            .font(.system(size: 22, weight: .bold))
                        Text("Saved")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("\(viewModel.lists.count)")
                            .font(.system(size: 22, weight: .bold))
                        Text("Folders")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("\(favoritesManager.visitedCount)")
                            .font(.system(size: 22, weight: .bold))
                        Text("Visited")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Menu Items
                VStack(spacing: 0) {
                    NavigationLink(destination: Text("My Saved Restaurants")) {
                        AccountMenuItem(icon: "bookmark.fill", title: "My Saved Restaurants", iconColor: .orange)
                    }
                    
                    Divider().padding(.leading, 56)
                    
                    NavigationLink(destination: Text("My Folders")) {
                        AccountMenuItem(icon: "folder.fill", title: "My Folders", iconColor: .blue)
                    }
                    
                    Divider().padding(.leading, 56)
                    
                    NavigationLink(destination: Text("Visited Places")) {
                        AccountMenuItem(icon: "checkmark.circle.fill", title: "Visited Places", iconColor: .green)
                    }
                    
                    Divider().padding(.leading, 56)
                    
                    NavigationLink(destination: Text("Favorites")) {
                        AccountMenuItem(icon: "heart.fill", title: "Favorites", iconColor: .red)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Account Actions
                VStack(spacing: 0) {
                    Button(action: {}) {
                        AccountMenuItem(icon: "arrow.triangle.2.circlepath", title: "Sync with Instagram", iconColor: .pink, showChevron: false)
                    }
                    
                    Divider().padding(.leading, 56)
                    
                    Button(action: {}) {
                        AccountMenuItem(icon: "square.and.arrow.up", title: "Share App", iconColor: .blue, showChevron: false)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Logout - only show when authenticated
                if isAuthenticated {
                    Button(action: signOut) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                            Text("Log Out")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer().frame(height: 32)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if isAuthenticated {
                await userManager.fetchCurrentUser()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showAuthView) {
            AuthView()
                .onDisappear {
                    isAuthenticated = Clerk.shared.user != nil
                    if isAuthenticated {
                        Task {
                            await userManager.fetchCurrentUser()
                            await viewModel.fetchHome()
                        }
                    }
                }
        }
        .onChange(of: userManager.currentUser) { _ in
            // Re-evaluate auth state when user changes (e.g. becomes nil on logout)
            isAuthenticated = Clerk.shared.user != nil
        }
        .onAppear {
            isAuthenticated = Clerk.shared.user != nil
        }
    }
    
    private func signOut() {
        Task {
            try? await AuthManager.shared.signOut()
            await MainActor.run {
                userManager.clearUser()
                favoritesManager.clearAll()
                isAuthenticated = false
                viewModel.unsortedRestaurants = []
                viewModel.lists = []
            }
        }
    }
}

struct AccountMenuItem: View {
    let icon: String
    let title: String
    let iconColor: Color
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.primary)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var bio = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Bio") {
                    TextEditor(text: $bio)
                        .frame(height: 100)
                }
                
                Section {
                    Button("Change Password") {
                        // Password change action
                    }
                    
                    Button("Delete Account") {
                        // Delete account action
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct FoldersView: View {
    @StateObject private var viewModel = HomeViewModel.shared
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.lists.count)")
                            .font(.system(size: 32, weight: .bold))
                        Text("Total Folders")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showAddFolder = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("New Folder")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(Capsule())
                    }
                }
                .padding()
                
                // Folders List
                if viewModel.lists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No folders yet")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Create folders to organize your saved restaurants")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.lists) { list in
                            NavigationLink(destination: ListDetailView(list: list)) {
                                FolderRowView(folder: list)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Folders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddFolder) {
            AddFolderView()
        }
    }
}

struct FolderRowView: View {
    let folder: UserList
    
    var body: some View {
        HStack(spacing: 16) {
            // Folder Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Tap to view")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    await HomeViewModel.shared.deleteList(folder)
                }
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }
}

struct AddFolderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var folderName = ""
    @State private var folderDescription = ""
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Folder Name", text: $folderName)
                    TextField("Description (Optional)", text: $folderDescription)
                }
                
                Section {
                    Button(action: createFolder) {
                        if isCreating {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Creating...")
                            }
                        } else {
                            Text("Create Folder")
                        }
                    }
                    .disabled(folderName.isEmpty || isCreating)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Folder '\(folderName)' created successfully!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createFolder() {
        print("DEBUG: createFolder called with name: '\(folderName)'")
        isCreating = true
        
        Task {
            do {
                print("DEBUG: Calling createList API...")
                let response = try await APIClient.shared.createList(name: folderName)
                print("DEBUG: createList succeeded, got response: \(response)")
                
                // Refresh home data
                print("DEBUG: Refreshing home data...")
                await HomeViewModel.shared.fetchHome()
                
                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                    print("DEBUG: Showing success alert")
                }
            } catch {
                print("DEBUG: createList failed with error: \(error)")
                print("DEBUG: Error localized description: \(error.localizedDescription)")
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create folder: \(error.localizedDescription)"
                    showError = true
                    print("DEBUG: Showing error alert with message: \(errorMessage)")
                }
            }
        }
    }
}

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var emailNotifications = false
    @State private var pushNotifications = true
    @State private var locationServices = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    
    var body: some View {
        Form {
            // Notifications
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    Toggle("Push Notifications", isOn: $pushNotifications)
                    Toggle("Email Notifications", isOn: $emailNotifications)
                }
            }
            
            // Privacy
            Section("Privacy") {
                Toggle("Location Services", isOn: $locationServices)
                
                NavigationLink(destination: Text("Privacy Policy")) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                
                NavigationLink(destination: Text("Terms of Service")) {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }
            }
            
            // Appearance
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $darkModeEnabled)
            }
            
            // Data & Storage
            Section("Data & Storage") {
                NavigationLink(destination: Text("Cache Settings")) {
                    HStack {
                        Label("Clear Cache", systemImage: "trash.fill")
                        Spacer()
                        Text("24 MB")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {}) {
                    Label("Export Data", systemImage: "square.and.arrow.up.fill")
                }
            }
            
            // Instagram Integration
            Section("Instagram") {
                NavigationLink(destination: Text("Connected Accounts")) {
                    Label("Connected Accounts", systemImage: "link.circle.fill")
                }
                
                Button(action: {}) {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            // Support
            Section("Support") {
                NavigationLink(destination: Text("Help Center")) {
                    Label("Help Center", systemImage: "questionmark.circle.fill")
                }
                
                NavigationLink(destination: Text("Contact Us")) {
                    Label("Contact Us", systemImage: "envelope.fill")
                }
                
                Button(action: {}) {
                    Label("Rate App", systemImage: "star.fill")
                }
            }
            
            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink(destination: Text("Licenses")) {
                    Text("Open Source Licenses")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon/Illustration
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red.opacity(0.7))
            }
            
            VStack(spacing: 12) {
                Text("Nothing saved yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add restaurants from Instagram using the + button above.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // CTA Button
            Button(action: onAddTapped) {
                Text("Add your first restaurant")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Add From Instagram View
struct AddFromInstagramView: View {
    @Environment(\.dismiss) var dismiss
    @State private var instagramLink = ""
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header Icon
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                    .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Add from Instagram")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Paste an Instagram post or reel link to save the restaurant")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instagram Link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                        
                        TextField("https://instagram.com/p/...", text: $instagramLink)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to get the link:")
                        .font(.system(size: 14, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("1.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("Open Instagram and find a restaurant post")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("2.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("Tap the three dots (•••) on the post")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("3.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("Select \"Copy Link\" and paste it here")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Add Button
                Button(action: addRestaurant) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Add Restaurant")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(instagramLink.isEmpty ? Color.gray : Color.red)
                .clipShape(Capsule())
                .padding(.horizontal)
                .padding(.bottom, 32)
                .disabled(instagramLink.isEmpty || isProcessing)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Restaurant link saved! It will appear on your home screen shortly.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addRestaurant() {
        isProcessing = true
        
        Task {
            do {
                let _ = try await APIClient.shared.saveEvent(url: instagramLink, caption: nil, listId: nil)
                
                // Refresh home data after saving
                await HomeViewModel.shared.fetchHome()
                
                await MainActor.run {
                    isProcessing = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Visited Places View
struct VisitedPlacesView: View {
    @StateObject private var viewModel = HomeViewModel.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var showFilterSheet = false
    
    // Filter restaurants that are marked as visited
    private var visitedRestaurants: [Restaurant] {
        viewModel.unsortedRestaurants.filter { restaurant in
            favoritesManager.isVisited(restaurant.id)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(visitedRestaurants.count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        Text("Places Visited")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filter")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                }
                .padding()
                
                // Visited Restaurants Grid
                if visitedRestaurants.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No visited places yet")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Mark restaurants as visited after you've been there")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(visitedRestaurants) { restaurant in
                            NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                                VisitedRestaurantCard(restaurant: restaurant)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Visited Places")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilterSheet) {
            FilterView()
        }
    }
}

struct VisitedRestaurantCard: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RestaurantCardView(restaurant: restaurant)
            
            // Visited checkmark badge
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                Text("Visited")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Favorites View
struct FavoritesView: View {
    @StateObject private var viewModel = HomeViewModel.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var showFilterSheet = false
    
    // Filter restaurants that are marked as favorites
    private var favoriteRestaurants: [Restaurant] {
        viewModel.unsortedRestaurants.filter { restaurant in
            favoritesManager.isFavorite(restaurant.id)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(favoriteRestaurants.count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.red)
                        Text("Favorites")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filter")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                }
                .padding()
                
                // Favorite Restaurants Grid
                if favoriteRestaurants.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No favorites yet")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Tap the heart icon on restaurants to add them to favorites")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(favoriteRestaurants) { restaurant in
                            NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                                FavoriteRestaurantCard(restaurant: restaurant)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilterSheet) {
            FilterView()
        }
    }
}

struct FavoriteRestaurantCard: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RestaurantCardView(restaurant: restaurant)
            
            // Favorite heart badge
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                Text("Favorite")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Filter View
struct FilterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPriceRange: Set<String> = []
    @State private var sortBy = "Recent"
    
    let priceRanges = ["$", "$$", "$$$", "$$$$"]
    let sortOptions = ["Recent", "Name", "Rating", "Distance"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Price Range") {
                    ForEach(priceRanges, id: \.self) { price in
                        Button(action: {
                            if selectedPriceRange.contains(price) {
                                selectedPriceRange.remove(price)
                            } else {
                                selectedPriceRange.insert(price)
                            }
                        }) {
                            HStack {
                                Text(price)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedPriceRange.contains(price) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                Section("Sort By") {
                    Picker("Sort By", selection: $sortBy) {
                        ForEach(sortOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button("Apply Filters") {
                        dismiss()
                    }
                    
                    Button("Reset") {
                        selectedPriceRange.removeAll()
                        sortBy = "Recent"
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

