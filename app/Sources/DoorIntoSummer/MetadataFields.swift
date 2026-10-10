struct MetadataField: Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

@MainActor
func fields(of post: PostModel) -> [MetadataField] {
    let job = post.job
    let shown = { (value: String?) in value ?? "unavailable" }
    return [
        MetadataField(key: "Model", value: shown(job?.model)),
        MetadataField(key: "Aspect ratio", value: shown(job?.aspect)),
        MetadataField(key: "Size", value: shown(job?.size)),
        MetadataField(key: "Resolution", value: shown(job?.resolution)),
        MetadataField(key: "Quality", value: shown(job?.quality)),
        MetadataField(key: "Mode", value: shown(job?.mode)),
        MetadataField(key: "Batch", value: shown(job?.batch.map(String.init))),
        MetadataField(key: "Input", value: post.generation == nil ? "unavailable" : post.original == nil ? "none" : "original photo"),
        MetadataField(key: "Job", value: shown(job?.id)),
        MetadataField(key: "Created", value: shown(job?.createdAt)),
        MetadataField(key: "Prompt", value: shown(job?.prompt)),
    ]
}
