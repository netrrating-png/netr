import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        bg: '#040406',
        surface: '#0F0F14',
        card: '#111116',
        border: '#1E1E26',
        muted: '#2A2A35',
        sub: '#6A6A82',
        neon: '#39FF14',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        neon: '0 0 20px rgba(57, 255, 20, 0.4)',
        'neon-sm': '0 0 10px rgba(57, 255, 20, 0.3)',
      },
    },
  },
  plugins: [],
}
export default config
