export type AuthUser = {
  id: string;
  name: string;
  role: 'passenger' | 'operator' | 'admin';
};
