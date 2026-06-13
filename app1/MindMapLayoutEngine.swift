import CoreGraphics
import Foundation

struct MindMapEdge: Identifiable, Equatable {
    var sourceID: UUID
    var targetID: UUID
    var sourcePosition: CGPoint
    var targetPosition: CGPoint

    var id: String {
        "\(sourceID.uuidString)-\(targetID.uuidString)"
    }
}

struct MindMapLayoutResult: Equatable {
    var nodes: [MindNode]
    var edges: [MindMapEdge]
}

enum MindMapLayoutEngine {
    static func layout(
        rootNode: MindNode,
        expandedNodeIDs: Set<UUID>,
        horizontalSpacing: CGFloat = 224,
        verticalSpacing: CGFloat = 108
    ) -> MindMapLayoutResult {
        var positionedNodes: [MindNode] = []
        var visibleIDs = Set<UUID>()
        var leafIndex: CGFloat = 0

        @discardableResult
        func place(_ node: MindNode) -> CGFloat {
            let visibleChildren = expandedNodeIDs.contains(node.id) ? node.children : []
            let childYValues = visibleChildren.map { place($0) }

            let y: CGFloat
            if childYValues.isEmpty {
                y = leafIndex * verticalSpacing
                leafIndex += 1
            } else {
                y = childYValues.reduce(0, +) / CGFloat(childYValues.count)
            }

            var copy = node
            copy.position = CGPoint(x: CGFloat(node.level) * horizontalSpacing, y: y)
            positionedNodes.append(copy)
            visibleIDs.insert(copy.id)
            return y
        }

        place(rootNode)

        guard !positionedNodes.isEmpty else {
            return MindMapLayoutResult(nodes: [], edges: [])
        }

        let minY = positionedNodes.map(\.position.y).min() ?? 0
        let maxY = positionedNodes.map(\.position.y).max() ?? 0
        let centerY = (minY + maxY) / 2
        let normalizedNodes = positionedNodes.map { node in
            var copy = node
            copy.position.y -= centerY
            return copy
        }
        let nodeByID = Dictionary(uniqueKeysWithValues: normalizedNodes.map { ($0.id, $0) })

        var edges: [MindMapEdge] = []
        func collectEdges(from node: MindNode) {
            guard visibleIDs.contains(node.id), expandedNodeIDs.contains(node.id) else { return }
            for child in node.children where visibleIDs.contains(child.id) {
                if let source = nodeByID[node.id], let target = nodeByID[child.id] {
                    edges.append(
                        MindMapEdge(
                            sourceID: source.id,
                            targetID: target.id,
                            sourcePosition: source.position,
                            targetPosition: target.position
                        )
                    )
                }
                collectEdges(from: child)
            }
        }
        collectEdges(from: rootNode)

        return MindMapLayoutResult(nodes: normalizedNodes, edges: edges)
    }
}
