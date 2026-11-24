import SwiftUI
import SwiftData

/// The Lists tab: checklists (shopping, packing, ideas) and free-form notes.
struct ListsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var lists: [NoteList]
    @Query private var entries: [ListEntry]
    @State private var path: [NoteList] = []
    @State private var query = ""

    private var store: Store { Store(context: context) }

    private var sorted: [NoteList] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return lists
            .filter { l in
                guard !q.isEmpty else { return true }
                if l.title.lowercased().contains(q) || l.body.lowercased().contains(q) { return true }
                return entries.contains { $0.listID == l.id && $0.text.lowercased().contains(q) }
            }
            .sorted { a, b in
                if a.pinned != b.pinned { return a.pinned }
                return a.updatedAt > b.updatedAt
            }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lists").font(.isle(.largeTitle)).foregroundStyle(T.ink)
                        Spacer()
                        Button { create(checklist: false) } label: { Image(systemName: "note.text.badge.plus") }
                            .buttonStyle(IconButtonStyle())
                            .accessibilityLabel("New note")
                        Button { create(checklist: true) } label: { Image(systemName: "plus") }
                            .buttonStyle(IconButtonStyle(fill: T.primary))
                            .accessibilityLabel("New list")
                    }

                    if !lists.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                            TextField("Search lists and notes", text: $query)
                                .font(.isle(.subheadline, .bold))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 12).fill(T.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.outline, lineWidth: 1.5))
                    }

                    if lists.isEmpty {
                        starters
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(sorted) { l in
                                NavigationLink(value: l) { ListCard(list: l, entries: entries.filter { $0.listID == l.id }) }
                                    .buttonStyle(PressStyle())
                                    .contextMenu {
                                        Button { l.pinned.toggle(); store.save() } label: {
                                            Label(l.pinned ? "Unpin" : "Pin to top", systemImage: l.pinned ? "pin.slash" : "pin")
                                        }
                                        Button(role: .destructive) {
                                            Feedback.play(.undo)
                                            withAnimation { store.delete(l) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: NoteList.self) { l in
                ListDetailView(list: l).environment(app)
            }
        }
    }

    private var starters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                PipView(mood: .happy, size: 54)
                Text("Keep shopping lists, packing lists, ideas and notes here. Anything on a list can go straight onto your day.")
                    .font(.isle(.subheadline, .bold)).foregroundStyle(T.ink)
            }
            .card()
            Text("Start with one").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
            IsleFlowLayout(spacing: 8) {
                ForEach(["Shopping", "To buy", "Packing", "Ideas", "Films to watch", "Gift ideas"], id: \.self) { name in
                    Button(name) { create(checklist: true, title: name) }
                        .buttonStyle(PillButtonStyle(fill: T.surface, height: 38))
                }
                Button("A note") { create(checklist: false, title: "Note") }
                    .buttonStyle(PillButtonStyle(fill: T.lilac, height: 38))
            }
        }
    }

    private func create(checklist: Bool, title: String = "") {
        Feedback.play(.lift)
        let l = store.addList(title: title, checklist: checklist)
        path.append(l)
    }
}

/// A tile on the Lists grid.
private struct ListCard: View {
    let list: NoteList
    let entries: [ListEntry]

    var body: some View {
        let open = entries.filter { !$0.done }.sorted { $0.order < $1.order }
        let done = entries.count - open.count
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(T.habit(list.colorIndex)).frame(width: 10, height: 10)
                Text(list.title.isEmpty ? (list.isChecklist ? "Untitled list" : "Untitled note") : list.title)
                    .font(.isle(.headline, .heavy)).foregroundStyle(T.ink).lineLimit(1)
                Spacer(minLength: 0)
                if list.pinned { Image(systemName: "pin.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(T.muted) }
            }
            if list.isChecklist {
                if entries.isEmpty {
                    Text("Empty").font(.isle(.caption, .bold)).foregroundStyle(T.muted)
                } else {
                    ForEach(open.prefix(4)) { e in
                        HStack(spacing: 5) {
                            Circle().strokeBorder(T.muted, lineWidth: 1.5).frame(width: 10, height: 10)
                            Text(e.text).font(.isle(.caption, .bold)).foregroundStyle(T.ink).lineLimit(1)
                        }
                    }
                    if open.count > 4 {
                        Text("+\(open.count - 4) more").font(.isle(.caption2, .heavy)).foregroundStyle(T.muted)
                    }
                    Spacer(minLength: 0)
                    Text(open.isEmpty ? "All ticked off" : "\(done) of \(entries.count) done")
                        .font(.isle(.caption2, .heavy)).foregroundStyle(open.isEmpty ? T.good : T.muted)
                }
            } else {
                Text(list.body.isEmpty ? "Empty note" : list.body)
                    .font(.isle(.caption, .semibold)).foregroundStyle(list.body.isEmpty ? T.muted : T.ink)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .card(fill: list.isChecklist ? T.surface : Color.dynamic(0xFFF6DC, 0x2E2A3F))
    }
}

/// One list or note, edited in place.
struct ListDetailView: View {
    @Bindable var list: NoteList
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [ListEntry]
    @State private var newText = ""
    @State private var showDone = false
    @State private var confirmDelete = false
    @State private var removed = false
    @FocusState private var focus: Field?

    enum Field: Hashable { case title, add, body }

    init(list: NoteList) {
        _list = Bindable(list)
        let id = list.id
        _entries = Query(filter: #Predicate<ListEntry> { $0.listID == id }, sort: \ListEntry.order)
    }

    private var store: Store { Store(context: context) }
    private var open: [ListEntry] { entries.filter { !$0.done } }
    private var done: [ListEntry] { entries.filter { $0.done } }

    var body: some View {
        VStack(spacing: 0) {
            TextField(list.isChecklist ? "List name" : "Note title", text: $list.title)
                .font(.isle(.title2, .heavy))
                .foregroundStyle(T.ink)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = list.isChecklist ? .add : .body }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            if list.isChecklist { checklist } else { note }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { list.pinned.toggle(); store.save() } label: {
                        Label(list.pinned ? "Unpin" : "Pin to top", systemImage: list.pinned ? "pin.slash" : "pin")
                    }
                    Menu {
                        ForEach(0..<8, id: \.self) { i in
                            Button { list.colorIndex = i; store.save() } label: {
                                Label("Colour \(i + 1)", systemImage: list.colorIndex == i ? "checkmark.circle.fill" : "circle.fill")
                            }
                        }
                    } label: { Label("Colour", systemImage: "paintpalette") }
                    if list.isChecklist && !open.isEmpty {
                        Button { addAllToToday() } label: { Label("Put everything on today", systemImage: "sun.max") }
                    }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 18, weight: .bold)).foregroundStyle(T.ink)
                }
            }
        }
        .confirmationDialog("Delete \(list.title.isEmpty ? "this" : list.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Feedback.play(.undo)
                removed = true
                store.delete(list)
                dismiss()
            }
        }
        .onAppear {
            if list.title.isEmpty { focus = .title } else if list.isChecklist && entries.isEmpty { focus = .add }
        }
        .onDisappear {
            guard !removed else { return }
            // A list left completely blank isn't worth keeping.
            if list.title.trimmingCharacters(in: .whitespaces).isEmpty && list.body.isEmpty && entries.isEmpty {
                store.delete(list)
            } else {
                store.save()
            }
        }
    }

    // MARK: checklist

    private var checklist: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(open) { e in entryRow(e) }
                        .onMove(perform: move)
                        .onDelete { idx in delete(idx.map { open[$0] }) }
                }
                if !done.isEmpty {
                    Section {
                        Button {
                            withAnimation { showDone.toggle() }
                        } label: {
                            HStack {
                                Text("Done · \(done.count)").font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .black)).foregroundStyle(T.muted)
                                    .rotationEffect(.degrees(showDone ? 90 : 0))
                                Spacer()
                                if showDone {
                                    Button("Clear") {
                                        Feedback.play(.whoosh)
                                        withAnimation { delete(done) }
                                    }
                                    .font(.isle(.caption, .heavy))
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        if showDone {
                            ForEach(done) { e in entryRow(e) }
                                .onDelete { idx in delete(idx.map { done[$0] }) }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.defaultMinListRowHeight, 46)

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(T.primary)
                TextField("Add an item", text: $newText)
                    .font(.isle(.body, .bold))
                    .focused($focus, equals: .add)
                    .submitLabel(.next)
                    .onSubmit(addItem)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(T.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(T.outline, lineWidth: 2))
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, focus == .add ? 8 : 84)
        }
    }

    private func entryRow(_ e: ListEntry) -> some View {
        HStack(spacing: 10) {
            Button {
                Feedback.play(e.done ? .undo : .tick)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    e.done.toggle()
                    list.updatedAt = Date()
                    store.save()
                }
            } label: {
                CheckCircle(done: e.done, size: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(e.done ? "Untick \(e.text)" : "Tick \(e.text)")

            TextField("Item", text: Binding(get: { e.text }, set: { e.text = $0 }))
                .font(.isle(.body, .bold))
                .foregroundStyle(e.done ? T.muted : T.ink)
                .strikethrough(e.done, color: T.muted)
                .onSubmit { store.save() }
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(T.line)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !e.done {
                Button { toToday(e) } label: { Label("Today", systemImage: "sun.max") }
                    .tint(T.primary)
            }
        }
    }

    private func addItem() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { focus = nil; return }
        Feedback.play(.chip(open.count % 10))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.addEntry(text, to: list)
            newText = ""
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            focus = .add
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = open
        items.move(fromOffsets: source, toOffset: destination)
        for (i, e) in items.enumerated() { e.order = i }
        IsleHaptics.play(.light)
        store.save()
    }

    private func delete(_ items: [ListEntry]) {
        for e in items { context.delete(e) }
        list.updatedAt = Date()
        store.save()
    }

    private func toToday(_ e: ListEntry) {
        Feedback.play(.place(Day.weekday(Day.today)))
        store.addTask(title: e.text, day: Day.today, start: nil, minutes: 30)
        app.showToast("“\(e.text)” is on today.")
    }

    private func addAllToToday() {
        Feedback.play(.whoosh)
        for e in open { store.addTask(title: e.text, day: Day.today, start: nil, minutes: 30) }
        app.showToast("Put \(open.count) item\(open.count == 1 ? "" : "s") on today.")
    }

    // MARK: note

    private var note: some View {
        TextEditor(text: $list.body)
            .font(.isle(.body, .semibold))
            .foregroundStyle(T.ink)
            .scrollContentBackground(.hidden)
            .focused($focus, equals: .body)
            .padding(.horizontal, 15)
            .padding(.bottom, focus == .body ? 0 : 84)
            .onChange(of: list.body) { _, _ in list.updatedAt = Date() }
    }
}
