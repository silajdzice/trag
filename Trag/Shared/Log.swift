import OSLog

/// App loggers. Never log amounts, names, merchants or account numbers as public.
enum Log {
    static let `import` = Logger(subsystem: "dev.edhem.trag", category: "import")
}
