import { useState, type FormEvent } from 'react';
import { ArrowRight, X } from 'lucide-react';
import { supabase } from './supabase';
import type { AuthUser } from './auth';
import './auth.css';

type Props = {
  user: AuthUser | null;
  onClose: () => void;
  onAuthenticated: (user: AuthUser) => void;
  onSignOut: () => void;
};

export default function AuthModal({ user, onClose, onAuthenticated, onSignOut }: Props) {
  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [role, setRole] = useState<'passenger' | 'operator'>('passenger');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMessage('');
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(cleanEmail)) {
      setMessage('Saisissez une adresse e-mail valide.');
      return;
    }
    if (mode === 'signup') {
      const cleanName = name.trim();
      if (cleanName.length < 2 || cleanName.length > 80) {
        setMessage('Le nom doit contenir entre 2 et 80 caractères.');
        return;
      }
      if (password.length < 8 || !/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
        setMessage('Le mot de passe doit contenir au moins 8 caractères, une lettre et un chiffre.');
        return;
      }
    }
    if (!supabase) {
      setMessage('Connexion sécurisée indisponible. Configurez les variables Supabase dans .env.local.');
      return;
    }

    setBusy(true);
    try {
      if (mode === 'signup') {
        const { data, error } = await supabase.auth.signUp({
          email: cleanEmail,
          password,
          options: { data: { full_name: name.trim() } },
        });
        if (error) throw error;
        if (data.user?.identities?.length === 0) {
          setMessage('Impossible de créer ce compte. Vérifiez les informations ou connectez-vous.');
        } else if (data.session && data.user) {
          const profile = await supabase.from('profiles').select('full_name,role').eq('id', data.user.id).single();
          if (profile.error || profile.data.role !== 'passenger') {
            const { error: signOutError } = await supabase.auth.signOut();
            if (signOutError) throw signOutError;
            throw new Error('Profil BLASTI absent. Appliquez les migrations Supabase 001 à 005 dans l’ordre, puis reconnectez-vous.');
          }
          onAuthenticated({ id: data.user.id, name: profile.data.full_name, role: profile.data.role });
          onClose();
        } else {
          setMessage('Compte créé. Confirmez votre adresse e-mail puis connectez-vous.');
          setMode('login');
        }
        return;
      }

      const { data, error } = await supabase.auth.signInWithPassword({ email: cleanEmail, password });
      if (error || !data.user) {
        setMessage('E-mail ou mot de passe incorrect.');
        return;
      }
      const profile = await supabase.from('profiles').select('full_name,role').eq('id', data.user.id).maybeSingle();
      if (profile.error || !profile.data) {
        await supabase.auth.signOut();
        setMessage('Compte non disponible. Vérifiez votre inscription ou contactez le support.');
        return;
      }
      if (role === 'operator' && !['operator', 'admin'].includes(profile.data.role)) {
        await supabase.auth.signOut();
        setMessage('Ce compte n’a pas accès à l’espace chauffeur.');
        return;
      }
      if (role === 'passenger' && profile.data.role !== 'passenger') {
        await supabase.auth.signOut();
        setMessage('Ce compte n’a pas accès à l’espace passager.');
        return;
      }
      onAuthenticated({ id: data.user.id, name: profile.data.full_name, role: profile.data.role });
      onClose();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Une erreur est survenue. Réessayez.');
    } finally {
      setBusy(false);
    }
  };

  const signOut = async () => {
    if (!supabase) return;
    setBusy(true);
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      onSignOut();
      onClose();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Déconnexion impossible.');
    } finally {
      setBusy(false);
    }
  };

  return <div className="modal-backdrop" onClick={onClose}>
    <section className="modal auth-modal" onClick={event => event.stopPropagation()}>
      <button className="modal-close" onClick={onClose} aria-label="Fermer"><X size={18}/></button>
      {user ? <>
        <h2>Bonjour {user.name}.</h2>
        <p className="modal-subtitle">Votre compte BLASTI est connecté.</p>
        {message && <p className="auth-message" role="alert">{message}</p>}
        <button className="button modal-confirm" disabled={busy} onClick={() => void signOut()}>
          Se déconnecter <ArrowRight size={16}/>
        </button>
      </> : <>
        <h2>{mode === 'signup' ? 'Créer un compte' : 'Connexion'}</h2>
        <p className="modal-subtitle">Vos réservations seront liées à votre compte.</p>
        <form onSubmit={event => void submit(event)}>
          {mode === 'signup' && <label className="input-label">Nom complet
            <input value={name} onChange={event => setName(event.target.value)} autoComplete="name" maxLength={80} required/>
          </label>}
          {mode === 'login' && <label className="input-label">Type de compte
            <select value={role} onChange={event => setRole(event.target.value as 'passenger' | 'operator')}>
              <option value="passenger">Passager</option><option value="operator">Chauffeur</option>
            </select>
          </label>}
          <label className="input-label">Adresse e-mail
            <input type="email" value={email} onChange={event => setEmail(event.target.value)} autoComplete="email" maxLength={254} required/>
          </label>
          <label className="input-label">Mot de passe
            <input type="password" value={password} onChange={event => setPassword(event.target.value)}
              autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} minLength={8} maxLength={128} required/>
          </label>
          {message && <p className="auth-message" role="alert">{message}</p>}
          <button className="button modal-confirm" disabled={busy} type="submit">
            {busy ? 'Patientez…' : mode === 'signup' ? 'Créer mon compte' : 'Me connecter'} <ArrowRight size={16}/>
          </button>
        </form>
        <button className="auth-toggle" onClick={() => { setMessage(''); setMode(mode === 'signup' ? 'login' : 'signup'); }}>
          {mode === 'signup' ? 'Déjà inscrit ? Se connecter' : 'Nouveau ? Créer un compte'}
        </button>
      </>}
    </section>
  </div>;
}
