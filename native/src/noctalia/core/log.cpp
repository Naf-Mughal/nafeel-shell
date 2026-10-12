// nafeel: Noctalia's logger (core/log.h) on Qt's logging, so the ported
// clipboard and secret-store code logs to the shell's log.

#include "core/log.h"

#include <QDebug>
#include <QString>

namespace {
LogLevel g_level = LogLevel::Info;
}

namespace detail {
void logMessage(LogLevel level, const char *section, std::string_view msg) {
  if (level < g_level)
    return;
  const QString text = QStringLiteral("nafeel: %1%2").arg(section ? QString::fromUtf8(section) + QStringLiteral(": ") : QString(), QString::fromUtf8(msg.data(), qsizetype(msg.size())));
  switch (level) {
  case LogLevel::Debug:
    qDebug().noquote() << text;
    break;
  case LogLevel::Info:
    qInfo().noquote() << text;
    break;
  case LogLevel::Warn:
    qWarning().noquote() << text;
    break;
  case LogLevel::Error:
    qCritical().noquote() << text;
    break;
  }
}
} // namespace detail

std::string_view logLevelName(LogLevel level) {
  switch (level) {
  case LogLevel::Debug:
    return "debug";
  case LogLevel::Info:
    return "info";
  case LogLevel::Warn:
    return "warn";
  case LogLevel::Error:
    return "error";
  }
  return "info";
}

std::optional<LogLevel> parseLogLevel(std::string_view value) {
  if (value == "debug")
    return LogLevel::Debug;
  if (value == "info")
    return LogLevel::Info;
  if (value == "warn")
    return LogLevel::Warn;
  if (value == "error")
    return LogLevel::Error;
  return std::nullopt;
}

LogLevel currentLogLevel() { return g_level; }
void setLogLevel(LogLevel level) { g_level = level; }
void initLogLevelFromEnvironment() {}
void initLogFile() {}
