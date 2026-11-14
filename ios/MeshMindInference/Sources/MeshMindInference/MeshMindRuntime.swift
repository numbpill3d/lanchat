import Foundation
import llama

public enum MeshMindRuntimeError: Error {
    case modelLoadFailed
    case contextLoadFailed
    case promptTokenizationFailed
    case decodeFailed
}

/// Small synchronous llama.cpp wrapper exposed to Flutter's method channel.
/// The Flutter layer owns routing and UI; this package owns model lifetime and
/// token generation on Apple devices.
public enum MeshMindRuntime {
    public static var backendName: String { "llama.cpp / Metal" }

    public static func generate(
        modelPath: String,
        prompt: String,
        maxTokens: Int32 = 256
    ) throws -> String {
        llama_backend_init()
        defer { llama_backend_free() }

        var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
#endif
        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            throw MeshMindRuntimeError.modelLoadFailed
        }
        defer { llama_model_free(model) }

        let threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_batch = 512
        contextParams.n_threads = Int32(threads)
        contextParams.n_threads_batch = Int32(threads)
        guard let context = llama_init_from_model(model, contextParams) else {
            throw MeshMindRuntimeError.contextLoadFailed
        }
        defer { llama_free(context) }

        let vocab = llama_model_get_vocab(model)
        let promptTokens = try tokenize(prompt, vocab: vocab)
        var batch = llama_batch_init(Int32(contextParams.n_batch), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(promptTokens.count)
        for (index, token) in promptTokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]![0] = 0
            batch.logits[index] = 0
        }
        batch.logits[promptTokens.count - 1] = 1
        guard llama_decode(context, batch) == 0 else {
            throw MeshMindRuntimeError.decodeFailed
        }

        var generated = ""
        var currentPosition = Int32(promptTokens.count)
        for _ in 0..<maxTokens {
            let nextToken = greedyToken(context: context, vocab: vocab, at: batch.n_tokens - 1)
            if llama_vocab_is_eog(vocab, nextToken) { break }
            generated += tokenPiece(nextToken, vocab: vocab)

            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = currentPosition
            batch.n_seq_id[0] = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0] = 1
            currentPosition += 1
            guard llama_decode(context, batch) == 0 else {
                throw MeshMindRuntimeError.decodeFailed
            }
        }
        return generated
    }

    private static func tokenize(
        _ text: String,
        vocab: OpaquePointer
    ) throws -> [llama_token] {
        let capacity = max(512, text.utf8.count + 32)
        var tokens = [llama_token](repeating: 0, count: capacity)
        let count = llama_tokenize(
            vocab,
            text,
            Int32(text.utf8.count),
            &tokens,
            Int32(tokens.count),
            true,
            true
        )
        guard count > 0 else { throw MeshMindRuntimeError.promptTokenizationFailed }
        return Array(tokens.prefix(Int(count)))
    }

    private static func greedyToken(
        context: OpaquePointer,
        vocab: OpaquePointer,
        at index: Int32
    ) -> llama_token {
        let logits = llama_get_logits_ith(context, index)!
        let count = Int(llama_vocab_n_tokens(vocab))
        var best = 0
        for candidate in 1..<count where logits[candidate] > logits[best] {
            best = candidate
        }
        return llama_token(best)
    }

    private static func tokenPiece(_ token: llama_token, vocab: OpaquePointer) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if length > 0 {
            return String(
                decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
        }
        guard length < 0 else { return "" }
        var expanded = [CChar](repeating: 0, count: Int(-length))
        let expandedLength = llama_token_to_piece(
            vocab,
            token,
            &expanded,
            Int32(expanded.count),
            0,
            false
        )
        guard expandedLength > 0 else { return "" }
        return String(
            decoding: expanded.prefix(Int(expandedLength)).map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }
}
