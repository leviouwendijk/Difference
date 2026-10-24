import Schema

// Serialized preflight views use Difference's native tree layout contract.
// The source of truth remains the typed Difference, not this projection.
extension TreeChangeKind: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .string(cases: allCases.map(\.rawValue))
    }
}

extension TreeDifferenceLayout: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                .init(name: "lines", schema: [Line].jsonschema, required: true),
            ],
            additionalProperties: .disallowed
        )
    }
}

extension TreeDifferenceLayout.Line: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                .init(name: "depth", schema: Int.jsonschema, required: true),
                .init(name: "is_last_child", schema: Bool.jsonschema, required: true),
                .init(name: "ancestor_last", schema: [Bool].jsonschema, required: true),
                .init(name: "change", schema: TreeChangeKind.jsonschema, required: true),
                .init(name: "label", schema: String.jsonschema, required: true),
                .init(name: "id", schema: String.jsonschema, required: true),
            ],
            additionalProperties: .disallowed
        )
    }
}
