import { Tabs, router } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Home, Ticket, UserRound, LayoutDashboard } from 'lucide-react-native';
import { colors } from '../src/theme';
import { useEffect } from 'react';
import { StoreProvider, useStore } from '../src/store';

export default function Layout() {
  return <StoreProvider><RootTabs/></StoreProvider>;
}
function RootTabs(){const {user}=useStore();useEffect(()=>{if(user?.role==='operator')router.replace('/operator');},[user?.role]);return <>
    <StatusBar style="dark" />
    <Tabs screenOptions={{ headerShown: false, tabBarActiveTintColor: colors.navy, tabBarInactiveTintColor: '#8995A4', tabBarStyle: { height: 64, paddingTop: 7, paddingBottom: 7, borderTopColor: '#E8EDF3', backgroundColor: '#FFFFFF' }, tabBarLabelStyle: { fontSize: 10, fontWeight: '600' } }}>
      <Tabs.Screen name="index" options={{ title: 'Dar', tabBarIcon: ({color,size})=><Home color={color} size={size}/> }} />
      <Tabs.Screen name="bookings" options={{ title: 'Mchwerati', tabBarIcon: ({color,size})=><Ticket color={color} size={size}/> }} />
      <Tabs.Screen name="operator" options={{ href:user?.role==='operator'||user?.role==='admin'?undefined:null, title: 'Chauffeur', tabBarIcon: ({color,size})=><LayoutDashboard color={color} size={size}/> }} />
      <Tabs.Screen name="profile" options={{ title: 'Compte', tabBarIcon: ({color,size})=><UserRound color={color} size={size}/> }} />
      <Tabs.Screen name="ticket" options={{ href: null }} />
      <Tabs.Screen name="booking" options={{ href: null }} />
    </Tabs>
  </>;
}
