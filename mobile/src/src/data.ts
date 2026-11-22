export type Trip = { id: string; from: string; to: string; time: string; kind: string; capacity: number; fare: number; filled: number; slots: number; lat: number; lng: number; fromLat: number; fromLng: number; status?:'scheduled'|'boarding'; currentStop?:string };
export type Booking = { id: string; tripId: string; name: string; passengerId?:string; seat: number; status: 'confirmed' | 'waitlisted' | 'checked_in' | 'completed' | 'cancelled'; slot: string; created: number; boardedAt?: number; droppedAt?: number; dropStop?: string };
export const destinations = ["M'saken", 'Monastir', 'Sahloul', 'Hergla'];
export const origins = ['Bab Bhar', 'Sahloul', "M'saken", 'Monastir', 'Hergla'];
export const places: Record<string,{latitude:number;longitude:number}> = {
  'Bab Bhar':{latitude:35.8254,longitude:10.6370},
  "M'saken":{latitude:35.7290,longitude:10.5800},
  'Monastir':{latitude:35.7770,longitude:10.8260},
  'Sahloul':{latitude:35.8370,longitude:10.6100},
  'Hergla':{latitude:36.0290,longitude:10.5090},
};
export const initialTrips: Trip[] = [
  { id: 'BB-0800', from:'Bab Bhar', to: "M'saken", time: '08:00', kind: 'Louage', capacity: 8, fare: 2.5, filled: 5, slots: 2, lat:places["M'saken"].latitude,lng:places["M'saken"].longitude, fromLat:places['Bab Bhar'].latitude, fromLng:places['Bab Bhar'].longitude },
  { id: 'BB-0830', from:'Bab Bhar', to: 'Monastir', time: '08:30', kind: 'Louage', capacity: 8, fare: 2.5, filled: 3, slots: 2, lat:places.Monastir.latitude,lng:places.Monastir.longitude, fromLat:places['Bab Bhar'].latitude, fromLng:places['Bab Bhar'].longitude },
  { id: 'BB-0900', from:'Bab Bhar', to: 'Sahloul', time: '09:00', kind: 'Taxi collectif', capacity: 6, fare: 2.5, filled: 2, slots: 2, lat:places.Sahloul.latitude,lng:places.Sahloul.longitude, fromLat:places['Bab Bhar'].latitude, fromLng:places['Bab Bhar'].longitude },
  { id: 'BB-0930', from:'Bab Bhar', to: 'Hergla', time: '09:30', kind: 'Bus', capacity: 12, fare: 2.5, filled: 8, slots: 3, lat:places.Hergla.latitude,lng:places.Hergla.longitude, fromLat:places['Bab Bhar'].latitude, fromLng:places['Bab Bhar'].longitude },
];
export const initialBookings: Booking[] = [
  { id: 'BL-7K2P9', tripId: 'BB-0800', name: 'Amira Ben Ali', seat: 1, status: 'confirmed', slot: '07:50 – 07:55', created: 1 },
  { id: 'BL-4M8Q1', tripId: 'BB-0800', name: 'Youssef Trabelsi', seat: 2, status: 'confirmed', slot: '07:50 – 07:55', created: 2 },
  { id: 'BL-2A6N3', tripId: 'BB-0800', name: 'Sana Khelifi', seat: 3, status: 'confirmed', slot: '07:55 – 08:00', created: 3 },
  { id: 'BL-9C5D2', tripId: 'BB-0800', name: 'Mehdi Mansour', seat: 4, status: 'confirmed', slot: '07:55 – 08:00', created: 4 },
  { id: 'BL-3P1R7', tripId: 'BB-0800', name: 'Rania Gharbi', seat: 5, status: 'confirmed', slot: '07:55 – 08:00', created: 5 },
];
export const money = (n: number) => `${Math.min(Math.max(n,0),2.5).toFixed(1).replace('.', ',')} DT`;
