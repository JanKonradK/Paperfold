/// A literal substring for SQLite LIKE, with `ESCAPE '\'` in the query.
String searchPattern(String keyword) =>
    '%${keyword.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
