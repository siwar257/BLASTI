import { useState, type FormEvent } from 'react';
import { Plus, ShieldCheck, X } from 'lucide-react';
import { createDeparture } from './backend';

type Props = {
  destinations: string[];
  onClose: () => void;
  onCreated: () => Promise<void>;
};

function initialDepartureTime() {
  const date = new Date(Date.now() + 60 * 60 * 1000);
  date.setSeconds(0, 0);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

export default function DepartureModal({ destinations, onClose, onCreated }: Props) {
  const [destination, setDestination] = useState(destinations[0] ?? '');
  const [departureAt, setDepartureAt] = useState(initialDepartureTime);
  const [fare, setFare] = useState('2.5');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');
    const parsedDate = new Date(departureAt);
    const parsedFare = Number(fare);
    if (!destinations.includes(destination)) {
      setError('Choisissez une destination disponible.');
      return;
    }
    if (!Number.isFinite(parsedFare) || parsedFare < 0 || parsedFare > 2.5) {
      setError('Le tarif doit être compris entre 0 et 2,5 DT.');
      return;
    }
    if (!Number.isFinite(parsedDate.getTime()) || parsedDate <= new Date()) {
      setError('Choisissez une date et une heure futures.');
      return;
    }
    setBusy(true);
    try {
      await createDeparture(destination, parsedDate, parsedFare);
      await onCreated();
      onClose();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Impossible de créer ce départ.');
    } finally {
      setBusy(false);
    }
  };

  return <div className="modal-backdrop" onClick={onClose}>
    <form className="modal departure-modal" onSubmit={event => void submit(event)} onClick={event => event.stopPropagation()}>
      <button type="button" className="modal-close" onClick={onClose} aria-label="Fermer"><X size={18}/></button>
      <span className="section-kicker">GESTION DES DÉPARTS</span>
      <h2>Nouveau départ</h2>
      <label className="input-label">Destination
        <select value={destination} onChange={event => setDestination(event.target.value)} required>
          {destinations.map(value => <option key={value} value={value}>{value}</option>)}
        </select>
      </label>
      <label className="input-label">Date et heure
        <input type="datetime-local" value={departureAt} onChange={event => setDepartureAt(event.target.value)} required/>
      </label>
      <label className="input-label">Tarif maximal : 2,5 DT
        <input type="number" value={fare} onChange={event => setFare(event.target.value)} step="0.1" min="0" max="2.5" required/>
      </label>
      {error && <p className="auth-message" role="alert">{error}</p>}
      <button className="button modal-confirm" type="submit" disabled={busy}>
        {busy ? 'Enregistrement…' : 'Créer le départ'} <Plus size={16}/>
      </button>
      <small className="demo-note"><ShieldCheck size={14}/> Capacité et véhicule validés côté serveur.</small>
    </form>
  </div>;
}
