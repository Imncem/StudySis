import type { DocumentData } from "firebase/firestore";
import type { Topic, TopicInput } from "../types.ts";

export function prepareNewTopic(input: TopicInput): TopicInput {
  return { ...input, status: "draft" };
}

export function mapTopicDocument(id: string, data: DocumentData): Topic {
  return {
    id,
    title: data.title ?? "Untitled topic",
    order: data.order ?? 0,
    status: data.status ?? "draft",
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  };
}
