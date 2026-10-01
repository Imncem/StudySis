type CodedError = {
  code?: unknown;
  message?: unknown;
};

export function isFirestoreUnavailable(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const { code, message } = error as CodedError;
  const normalizedCode = typeof code === "string" ? code.toLowerCase() : "";
  const normalizedMessage = typeof message === "string" ? message.toLowerCase() : "";

  return normalizedCode === "unavailable" ||
    normalizedCode === "firestore/unavailable" ||
    normalizedMessage.includes("client is offline") ||
    normalizedMessage.includes("could not reach cloud firestore") ||
    normalizedMessage.includes("network request failed");
}
