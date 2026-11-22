import { supabase } from './supabase';

export type LiveTrip = {
  id: string;
  to: string;
  time: string;
  kind: string;
  capacity: number;
  fare: number;
  filled: number;
  slots: number;
};

export type LiveBooking = {
  id: string;
  tripId: string;
  name: string;
  seat: number;
  status: 'confirmed' | 'waitlisted' | 'cancelled';
  slot: string;
  created: number;
};

type TripRow = {
  id: string;
  departure_at: string;
  fare: number;
  boarding_group_size: number;
  reserved_seats: number;
  routes: { destination: string } | { destination: string }[];
  vehicles: { transport_type: string; capacity: number } | { transport_type: string; capacity: number }[];
};

type BookingRow = {
  reference: string;
  departure_id: string;
  seat_number: number | null;
  status: string;
  boarding_start: string | null;
  boarding_end: string | null;
  created_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

function client() {
  if (!supabase) throw new Error('Connexion sécurisée indisponible. Configurez Supabase.');
  return supabase;
}

export async function loadLiveTrips(): Promise<LiveTrip[]> {
  const { data, error } = await client().from('departures')
    .select('id,departure_at,fare,boarding_group_size,reserved_seats,routes!inner(destination),vehicles!inner(transport_type,capacity)')
    .in('status', ['scheduled', 'boarding'])
    .order('departure_at');
  if (error) throw error;
  return (data as TripRow[]).map(row => {
    const route = Array.isArray(row.routes) ? row.routes[0] : row.routes;
    const vehicle = Array.isArray(row.vehicles) ? row.vehicles[0] : row.vehicles;
    return {
      id: row.id,
      to: route.destination,
      time: new Date(row.departure_at).toLocaleTimeString('fr-TN', { hour: '2-digit', minute: '2-digit' }),
      kind: vehicle.transport_type,
      capacity: vehicle.capacity,
      fare: Number(row.fare),
      filled: row.reserved_seats,
      slots: row.boarding_group_size,
    };
  });
}

export async function loadLiveBookings(): Promise<LiveBooking[]> {
  const { data, error } = await client().from('reservations')
    .select('reference,departure_id,seat_number,status,boarding_start,boarding_end,created_at,profiles(full_name)')
    .in('status', ['confirmed', 'waitlisted'])
    .order('created_at');
  if (error) throw error;
  return (data as BookingRow[]).map(row => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const slot = row.boarding_start && row.boarding_end
      ? `${new Date(row.boarding_start).toLocaleTimeString('fr-TN', { hour: '2-digit', minute: '2-digit' })} – ${new Date(row.boarding_end).toLocaleTimeString('fr-TN', { hour: '2-digit', minute: '2-digit' })}`
      : 'En attente';
    return {
      id: row.reference,
      tripId: row.departure_id,
      name: profile?.full_name ?? 'Passager',
      seat: Number(row.seat_number ?? 0),
      status: row.status as LiveBooking['status'],
      slot,
      created: new Date(row.created_at).getTime(),
    };
  });
}

export async function reserveSeat(departureId: string, seatNumber: number) {
  const { data, error } = await client().rpc('reserve_seat', {
    p_departure_id: departureId,
    p_seat_number: seatNumber,
  });
  if (error) throw error;
  return data as { reference: string };
}

export async function cancelReservation(reference: string) {
  const { error } = await client().rpc('cancel_reservation', { p_reference: reference });
  if (error) throw error;
}

export async function joinWaitingList(departureId: string) {
  const { error } = await client().rpc('join_waiting_list', { p_departure_id: departureId });
  if (error) throw error;
}

export async function createDeparture(destination: string, departureAt: Date, fare: number) {
  if (!destination.trim() || destination.trim().length > 80) throw new Error('Destination invalide.');
  if (!(departureAt instanceof Date) || !Number.isFinite(departureAt.getTime()) || departureAt <= new Date()) {
    throw new Error('Le départ doit être prévu dans le futur.');
  }
  if (!Number.isFinite(fare) || fare < 0 || fare > 2.5) throw new Error('Le tarif doit être compris entre 0 et 2,5 DT.');
  const { error } = await client().rpc('create_departure', {
    p_origin: 'Bab Bhar',
    p_destination: destination.trim(),
    p_departure_at: departureAt.toISOString(),
    p_fare: fare,
  });
  if (error) throw error;
}
