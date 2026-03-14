import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://beko2210.github.io',
  base: '/Prompt_Copyrighting',
  vite: {
    plugins: [tailwindcss()],
  },
});
