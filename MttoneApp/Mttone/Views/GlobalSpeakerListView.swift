import SwiftUI

struct GlobalSpeakerListView: View {
    @Environment(DatabaseManager.self) private var databaseManager
    @State private var contacts: [Contact] = []
    
    var body: some View {
        List(contacts) { contact in
            NavigationLink(destination: SpeakerDetailView(contact: contact)) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.name)
                            .font(.headline)
                        Text("已记录在系统中")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("声纹字典管理")
        .onAppear {
            contacts = databaseManager.fetchAllContacts()
        }
    }
}
