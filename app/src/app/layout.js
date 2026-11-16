import './globals.css';
import Navbar from '@/components/Navbar';

export const metadata = { title: 'HFT Platform', description: 'High Frequency Trading database project' };

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <Navbar />
        <main>{children}</main>
      </body>
    </html>
  );
}
