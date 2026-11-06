import Schema

extension GraphChangeKind: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .string(cases: allCases.map(\.rawValue))
    }
}

extension GraphDifferenceLayout: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(properties: [
            .init(name: "nodes", schema: [Node].jsonschema, required: true),
            .init(name: "edges", schema: [Edge].jsonschema, required: true),
        ], additionalProperties: .disallowed)
    }
}

extension GraphDifferenceLayout.Presentation: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(properties: [
            .init(name: "label", schema: String.jsonschema, required: true),
            .init(name: "detail", schema: String.jsonschema, required: false),
        ], additionalProperties: .disallowed)
    }
}

extension GraphDifferenceLayout.Endpoints: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(properties: [
            .init(name: "source", schema: String.jsonschema, required: true),
            .init(name: "destination", schema: String.jsonschema, required: true),
        ], additionalProperties: .disallowed)
    }
}

extension GraphDifferenceLayout.Node: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(properties: [
            .init(name: "id", schema: String.jsonschema, required: true),
            .init(name: "change", schema: GraphChangeKind.jsonschema, required: true),
            .init(name: "before", schema: GraphDifferenceLayout.Presentation.jsonschema, required: false),
            .init(name: "after", schema: GraphDifferenceLayout.Presentation.jsonschema, required: false),
        ], additionalProperties: .disallowed)
    }
}

extension GraphDifferenceLayout.Edge.State: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(properties: [
            .init(name: "endpoints", schema: GraphDifferenceLayout.Endpoints.jsonschema, required: true),
            .init(name: "presentation", schema: GraphDifferenceLayout.Presentation.jsonschema, required: true),
        ], additionalProperties: .disallowed)
    }
}

extension GraphDifferenceLayout.Edge: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(properties: [
            .init(name: "id", schema: String.jsonschema, required: true),
            .init(name: "change", schema: GraphChangeKind.jsonschema, required: true),
            .init(name: "before", schema: State.jsonschema, required: false),
            .init(name: "after", schema: State.jsonschema, required: false),
        ], additionalProperties: .disallowed)
    }
}
