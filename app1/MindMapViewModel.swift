import CoreGraphics
import Combine
import Foundation
import SwiftUI

@MainActor
final class MindMapViewModel: ObservableObject {
    @Published private(set) var rootNode: MindNode
    @Published var selectedNodeID: UUID?
    @Published var focusedNodeID: UUID?
    @Published var expandedNodeIDs: Set<UUID>
    @Published var scale: CGFloat
    @Published var offset: CGSize

    @Published private var layoutResult: MindMapLayoutResult

    convenience init() {
        self.init(rootNode: MindNode.algorithmTree())
    }

    init(rootNode: MindNode) {
        self.rootNode = rootNode
        self.selectedNodeID = rootNode.id
        self.focusedNodeID = rootNode.id
        self.expandedNodeIDs = [rootNode.id]
        self.scale = 1
        self.offset = CGSize(width: 74, height: 210)
        self.layoutResult = MindMapLayoutEngine.layout(rootNode: rootNode, expandedNodeIDs: [rootNode.id])
    }

    var visibleNodes: [MindNode] {
        layoutResult.nodes
    }

    var visibleEdges: [MindMapEdge] {
        layoutResult.edges
    }

    var selectedNode: MindNode {
        if let selectedNodeID, let node = rootNode.find(id: selectedNodeID) {
            return node
        }
        return rootNode
    }

    var selectedKnowledgeDetail: KnowledgeDetail {
        KnowledgeRepository.detail(for: selectedNode, path: selectedPathText)
    }

    var selectedGraphRelatedNodes: [RelatedKnowledgeNode] {
        guard let selectedNodeID = selectedNodeID,
              let path = rootNode.path(to: selectedNodeID) else {
            return rootNode.children.map { RelatedKnowledgeNode(relation: "后驱", title: $0.title) }
        }

        let current = path.last ?? rootNode
        var results: [RelatedKnowledgeNode] = []
        if path.count > 1 {
            results.append(RelatedKnowledgeNode(relation: "前驱", title: path[path.count - 2].title))
        }
        results.append(RelatedKnowledgeNode(relation: "当前位置", title: current.title))
        results.append(contentsOf: current.children.map { RelatedKnowledgeNode(relation: "后驱", title: $0.title) })
        return results
    }

    var selectedPathText: String {
        guard let selectedNodeID, let path = rootNode.path(to: selectedNodeID) else {
            return rootNode.title
        }
        return path.map(\.title).joined(separator: " / ")
    }

    func selectNode(_ node: MindNode) {
        selectedNodeID = node.id
        focusedNodeID = node.id
        toggleExpand(node.id)
    }

    func jumpToNode(title: String) {
        guard let node = rootNode.find(title: title) else { return }
        selectedNodeID = node.id
        focusedNodeID = node.id
        expandPath(to: node.id)
        if !node.children.isEmpty {
            expandedNodeIDs.insert(node.id)
        }
        refreshLayout()
    }

    func toggleExpand(_ nodeID: UUID) {
        guard let node = rootNode.find(id: nodeID), !node.children.isEmpty else {
            refreshLayout()
            return
        }

        if expandedNodeIDs.contains(nodeID) {
            expandedNodeIDs.remove(nodeID)
            expandedNodeIDs.subtract(node.descendantIDs())
        } else {
            expandedNodeIDs.insert(nodeID)
        }
        refreshLayout()
    }

    func isNodeVisible(_ node: MindNode) -> Bool {
        visibleNodes.contains { $0.id == node.id }
    }

    func isNodeInFocusedBranch(_ node: MindNode) -> Bool {
        guard let focusedNodeID else { return true }
        guard let focusedNode = rootNode.find(id: focusedNodeID),
              let currentNode = rootNode.find(id: node.id) else {
            return true
        }

        let isAncestorOfFocus = currentNode.contains(id: focusedNodeID)
        let isDescendantOfFocus = focusedNode.contains(id: node.id)
        return isAncestorOfFocus || isDescendantOfFocus
    }

    func isEdgeInFocusedBranch(_ edge: MindMapEdge) -> Bool {
        guard let source = rootNode.find(id: edge.sourceID),
              let target = rootNode.find(id: edge.targetID) else {
            return true
        }
        return isNodeInFocusedBranch(source) && isNodeInFocusedBranch(target)
    }

    func resetView() {
        selectedNodeID = rootNode.id
        focusedNodeID = rootNode.id
        expandedNodeIDs = [rootNode.id]
        scale = 1
        offset = CGSize(width: 74, height: 210)
        refreshLayout()
    }

    func replaceRoot(_ rootNode: MindNode, focusingRemoteID: String? = nil) {
        self.rootNode = rootNode
        let focusedNode = focusingRemoteID.flatMap { rootNode.find(remoteID: $0) } ?? rootNode
        selectedNodeID = focusedNode.id
        focusedNodeID = focusedNode.id
        expandedNodeIDs = [rootNode.id]
        expandPath(to: focusedNode.id)
        if !focusedNode.children.isEmpty {
            expandedNodeIDs.insert(focusedNode.id)
        }
        scale = 1
        offset = CGSize(width: 74, height: 210)
        refreshLayout()
    }

    func clampedScale(_ value: CGFloat) -> CGFloat {
        min(2.2, max(0.5, value))
    }

    func gentlyCenter(nodeID: UUID, in canvasSize: CGSize) {
        guard let node = visibleNodes.first(where: { $0.id == nodeID }) else { return }
        let screenPoint = CGPoint(
            x: node.position.x * scale + offset.width,
            y: node.position.y * scale + offset.height
        )
        let delta = CGSize(
            width: canvasSize.width / 2 - screenPoint.x,
            height: canvasSize.height / 2 - screenPoint.y
        )
        // TODO: tune this factor once the full learning screen has more real content.
        offset.width += delta.width * 0.18
        offset.height += delta.height * 0.18
    }

    private func refreshLayout() {
        layoutResult = MindMapLayoutEngine.layout(rootNode: rootNode, expandedNodeIDs: expandedNodeIDs)
    }

    private func expandPath(to nodeID: UUID) {
        guard let path = rootNode.path(to: nodeID) else { return }
        for ancestor in path.dropLast() {
            expandedNodeIDs.insert(ancestor.id)
        }
    }
}
