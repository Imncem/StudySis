export type Student = {
  name?: string;
  displayName?: string;
  preferredLanguage: string;
  dailyTargetMinutes: number;
  status: string;
};

export type Subject = {
  id: string;
  displayName: string;
  shortName: string;
  contentStatus: string;
  iconName: string;
  themeColor: string;
  order: number;
};
