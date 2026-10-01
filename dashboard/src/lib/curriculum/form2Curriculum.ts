import { mathematicsChapterSeed } from "../seeds/mathematics-chapters.ts";
import type {
  CurriculumItem,
  CurriculumMetadata,
} from "../types.ts";

export type Form2Curriculum = CurriculumMetadata & {
  subjectKey: Form2SubjectKey;
  firestoreSubjectId: string;
  items: Form2CurriculumItem[];
  curriculumSource?: string;
  curriculumSourceNote?: string;
};

export type Form2CurriculumItem = CurriculumItem;

export type Form2SubjectKey =
  | "bahasaMelayu"
  | "english"
  | "mathematics"
  | "science"
  | "sejarah"
  | "geography"
  | "rekaBentukTeknologi"
  | "pendidikanIslam"
  | "pendidikanJasmani"
  | "seni";

const mathematicsItems: CurriculumItem[] = mathematicsChapterSeed.map(
  (title, index) => ({
    order: index + 1,
    sequenceLabel: String(index + 1),
    title,
    status: "draft",
  }),
);

function draftBahasaMelayuUnits(): CurriculumItem[] {
  const themes: readonly [string, string, string][] = [
    ["Kesihatan dan Kebersihan", "Anda Sihat Anda Ceria", "Kebersihan Lambang Keperibadian"],
    ["Menimba Ilmu", "Indahnya Menuntut Ilmu", "Ilmu Penyuluh Hidup"],
    ["Kerjaya ke Mercu Impian", "Cita-cita Setinggi Bintang", "Budi Disemai, Bakti Dituai"],
    ["Integriti Amalan Kita", "Remaja Berintegriti", "Integrasi Teras Kehidupan"],
    ["Bahasa dan Sastera", "Bahasaku di Persada Dunia", "Indah Sastera, Cantik Bahasa"],
    ["Teladani Sejarah Hargai Warisan", "Sejarah Kita", "Pusaka Tanah Air"],
    ["Indah Seni Gah Budaya", "Warna-warni Budaya", "Segalanya Bermula di Sini"],
    ["Utamakan Keselamatan", "Keselamatan Diri", "Anda Prihatin, Anda Selamat"],
    ["Sukan dan Rekreasi", "Sukan Milik Semua", "Seronoknya Beriadah"],
    ["Selamat Datang ke Malaysia", "Kenali Malaysia", "Cintai Malaysia"],
    ["Perpaduan", "Indahnya Ukhuwah", "Teras Keharmonian"],
    ["Negaraku Jati Diriku", "Semarak Negara", "Hayati Rukun Negara"],
    ["Ekonomi, Keusahawanan dan Pengurusan Kewangan", "Ekonomi dan Perniagaan", "Bijak Wang"],
    ["Berbudi kepada Alam", "Suburnya Bumiku", "Di Tanah dan di Air"],
    ["Sains, Teknologi dan Inovasi", "Hebatnya Teknologi", "Dunia Kreativiti"],
    ["Pelestarian Alam", "Dunia Hanya Pinjaman", "Buana Menguntum Senyum"],
    ["Era Baharu Industri", "Industri Berdaya Saing", "Industri Berdaya Maju"],
    ["Pentadbiran dan Politik", "Patriot Bangsa", "Pemimpin Berjasa, Negara Berjaya"],
  ];

  return themes.flatMap(([theme, firstUnit, secondUnit], themeIndex) =>
    [firstUnit, secondUnit].map((title, unitIndex) => {
      const order = themeIndex * 2 + unitIndex + 1;
      return {
        order,
        sequenceLabel: `Unit ${order}`,
        title,
        group: `Tema ${themeIndex + 1}: ${theme}`,
        status: "draft" as const,
      };
    }),
  );
}

function draftPjkUnits(): CurriculumItem[] {
  const sections = [
    {
      group: "Pendidikan Jasmani",
      titles: [
        "Gimnastik Asas",
        "Pergerakan Berirama",
        "Permainan Kategori Serangan",
        "Permainan Kategori Jaring",
        "Permainan Kategori Memadang",
        "Olahraga Asas",
        "Rekreasi dan Kesenggangan",
        "Kecergasan",
      ],
    },
    {
      group: "Pendidikan Kesihatan",
      titles: [
        "Pendidikan Kesihatan Reproduktif dan Sosial (PEERS)",
        "Pemakanan",
        "Pertolongan Cemas",
      ],
    },
  ];

  return sections
    .flatMap(({ group, titles }) =>
      titles.map((title, index) => ({
        sequenceLabel: `Unit ${index + 1}`,
        title,
        group,
        status: "draft" as const,
      })),
    )
    .map((item, index) => ({ order: index + 1, ...item }));
}

function draftPendidikanIslamLessons(
  lessons: readonly { title: string; group: string }[],
): Form2CurriculumItem[] {
  return lessons.map(({ title, group }, index) => ({
    order: index + 1,
    sequenceLabel: `Pelajaran ${index + 1}`,
    title,
    group,
    status: "draft",
  }));
}

function draftSeniTopics(titles: readonly string[]): Form2CurriculumItem[] {
  return titles.map((title, index) => ({
    order: index + 1,
    sequenceLabel: `Tajuk ${index + 1}`,
    title,
    status: "draft",
  }));
}

function draftChapterItems(titles: readonly string[]): CurriculumItem[] {
  return titles.map((title, index) => ({
    order: index + 1,
    sequenceLabel: `Chapter ${index + 1}`,
    title,
    status: "draft",
  }));
}

export const form2Curriculum: readonly Form2Curriculum[] = [
  {
    subjectKey: "bahasaMelayu",
    firestoreSubjectId: "bahasa_melayu",
    curriculum: "KSSM",
    form: 2,
    structureType: "unit",
    structureLabelSingular: "Unit",
    structureLabelPlural: "Units",
    curriculumSource: "KSSM Form 2 Bahasa Melayu textbook",
    curriculumSourceNote:
      "Tema and Unit sequence verified against textbook contents pages iv-v and introduction page vi: https://fliphtml5.com/lmvnm/vzks/BUKU_TEKS_KSSM_BAHASA_MELAYU_TINGKATAN_2/; Ministry-linked textbook listing: https://sites.google.com/moe-dl.edu.my/bm-t2-smektas/buku-teks-digital.",
    items: draftBahasaMelayuUnits(),
  },
  {
    subjectKey: "english",
    firestoreSubjectId: "english",
    curriculum: "KSSM",
    form: 2,
    structureType: "unit",
    structureLabelSingular: "Unit",
    structureLabelPlural: "Units",
    curriculumSource: "Pulse 2 textbook and Secondary Form 2 English Scheme of Work",
    curriculumSourceNote:
      "Pulse 2 supplies textbook Unit identity (Units 6-9): https://anyflip.com/ipgjv/xibd/basic; Ministry-linked Form 2 resource: https://sites.google.com/moe-dl.edu.my/englishyoume/home/form-2. Theme groups come from the Secondary Form 2 Scheme of Work: https://alia.samsulzamzuri.com/wp-content/uploads/2024/08/SOW-Form-2.pdf; Ministry-linked SoW library: https://sites.google.com/moe-dl.edu.my/englishpanelsmkb/dskp-sow-bahasa-inggeris/scheme-of-work-sow. These four items cover the textbook component only, not the complete SoW. KSSM/CEFR standards are separate from textbook numbering; SK/SP mappings are not populated.",
    items: [
      {
        order: 1,
        sequenceLabel: "Unit 6",
        title: "Money",
        group: "Consumerism and Financial Awareness",
        status: "draft",
      },
      {
        order: 2,
        sequenceLabel: "Unit 7",
        title: "Journeys",
        group: "People and Culture",
        status: "draft",
      },
      {
        order: 3,
        sequenceLabel: "Unit 8",
        title: "Good luck, bad luck",
        group: "People and Culture",
        status: "draft",
      },
      {
        order: 4,
        sequenceLabel: "Unit 9",
        title: "Take care",
        group: "Health and Environment",
        status: "draft",
      },
    ],
  },
  {
    subjectKey: "mathematics",
    firestoreSubjectId: "math",
    curriculum: "KSSM",
    form: 2,
    structureType: "chapter",
    structureLabelSingular: "Chapter",
    structureLabelPlural: "Chapters",
    items: mathematicsItems,
  },
  {
    subjectKey: "science",
    firestoreSubjectId: "science",
    curriculum: "KSSM",
    form: 2,
    structureType: "chapter",
    structureLabelSingular: "Chapter",
    structureLabelPlural: "Chapters",
    curriculumSource: "KSSM Form 2 Science textbook",
    curriculumSourceNote:
      "Textbook table of contents; digitized textbook reference: https://dev.kancilscience.my/2023/04/buku-teks-sains-tingkatan-2/.",
    items: draftChapterItems([
      "Biodiversiti",
      "Ekosistem",
      "Nutrisi",
      "Kesihatan Manusia",
      "Air dan Larutan",
      "Asid dan Alkali",
      "Keelektrikan dan Kemagnetan",
      "Daya dan Gerakan",
      "Haba",
      "Gelombang Bunyi",
      "Bintang dan Galaksi dalam Alam Semesta",
      "Sistem Suria",
      "Meteoroid, Asteroid dan Komet",
    ]),
  },
  {
    subjectKey: "sejarah",
    firestoreSubjectId: "sejarah",
    curriculum: "KSSM",
    form: 2,
    structureType: "chapter",
    structureLabelSingular: "Chapter",
    structureLabelPlural: "Chapters",
    curriculumSource: "KSSM Form 2 Sejarah textbook",
    curriculumSourceNote:
      "Sejarah Tingkatan 2 textbook PDF hosted by Jabatan Muzium Malaysia: http://ipim.jmm.gov.my/sites/default/files/file1p1m/Buku%20Teks%20Sejarah%20Tingkatan%202.pdf.",
    items: draftChapterItems([
      "Kerajaan Alam Melayu",
      "Sistem Pemerintahan dan Kegiatan Ekonomi Masyarakat Kerajaan Alam Melayu",
      "Sosiobudaya Masyarakat Kerajaan Alam Melayu",
      "Agama, Kepercayaan dan Keunikan Warisan Masyarakat Kerajaan Alam Melayu",
      "Kesultanan Melayu Melaka",
      "Kesultanan Johor Riau",
      "Kesultanan Melayu Pahang, Perak, Terengganu dan Selangor",
      "Kerajaan Kedah, Kelantan, Negeri Sembilan dan Perlis",
      "Warisan Kerajaan-kerajaan Melayu",
      "Sarawak dan Sabah",
    ]),
  },
  {
    subjectKey: "geography",
    firestoreSubjectId: "geography",
    curriculum: "KSSM",
    form: 2,
    structureType: "chapter",
    structureLabelSingular: "Chapter",
    structureLabelPlural: "Chapters",
    curriculumSource: "KSSM Form 2 Geography textbook",
    curriculumSourceNote:
      "Chapter headings cross-checked against the Ministry-linked Form 2 Geography learning page and its textbook link: https://sites.google.com/moe-dl.edu.my/epembelajaransmkbrp/e-pembelajaran-t2/geografi-t2.",
    items: draftChapterItems([
      "Skala dan Jarak",
      "Peta Topografi",
      "Pengaruh Pergerakan Bumi terhadap Cuaca dan Iklim",
      "Cuaca dan Iklim di Malaysia",
      "Pengangkutan di Malaysia",
      "Telekomunikasi di Malaysia",
      "Kepelbagaian Iklim dan Pengaruhnya terhadap Kegiatan Manusia di Asia",
      "Jenis dan Kemajuan Pengangkutan di Asia",
      "Pemanasan Global",
      "Teknologi Hijau",
      "Panduan Kerja Lapangan",
    ]),
  },
  {
    subjectKey: "rekaBentukTeknologi",
    firestoreSubjectId: "rbt",
    curriculum: "KSSM",
    form: 2,
    structureType: "chapter",
    structureLabelSingular: "Chapter",
    structureLabelPlural: "Chapters",
    curriculumSource: "KSSM Form 2 Reka Bentuk dan Teknologi textbook",
    curriculumSourceNote:
      "Top-level chapters cross-checked against Ministry-linked materials (https://sites.google.com/moe-dl.edu.my/rbt-menengah-kssm-sir-b-nathan/nota/nota-tingkatan-2) and textbook contents (https://studentportal.my/wp-content/uploads/2023/03/Buku-Teks-RBT-Tingkatan-2.pdf); 2.1-2.6 are subsections of Chapter 2.",
    items: draftChapterItems([
      "Penyelesaian Masalah Secara Inventif",
      "Aplikasi Teknologi",
    ]),
  },
  {
    subjectKey: "pendidikanIslam",
    firestoreSubjectId: "pendidikan_islam",
    curriculum: "KSSM",
    form: 2,
    structureType: "lesson",
    structureLabelSingular: "Lesson",
    structureLabelPlural: "Lessons",
    curriculumSource: "KSSM Form 2 Pendidikan Islam textbook",
    curriculumSourceNote:
      "Lesson order, titles, and bidang groups cross-checked against the Ministry-linked Form 2 learning page and its textbook link: https://sites.google.com/moe-dl.edu.my/epembelajaransmkbrp/e-pembelajaran-t2/p-islam-t2.",
    items: draftPendidikanIslamLessons([
      { title: "Allah SWT Pengurnia Hidayah", group: "Al-Quran" },
      { title: "Hanya Allah Yang Maha Esa", group: "Al-Quran" },
      { title: "Luasnya Kuasa Allah", group: "Al-Quran" },
      { title: "Mudahnya Tajwid", group: "Al-Quran" },
      { title: "Manisnya Persaudaraan", group: "Al-Quran" },
      { title: "Mengharap Keampunan", group: "Al-Quran" },
      { title: "Kesantunan Dakwah Rasulullah SAW", group: "Al-Quran" },
      { title: "Amanah Terhadap Harta dan Nyawa", group: "Al-Quran" },
      { title: "Mungkar Dicegah Hidup Berkat", group: "Hadis" },
      { title: "Mencari Yang Halal", group: "Hadis" },
      { title: "Kekuatan dan Kekuasaan Allah", group: "Akidah" },
      { title: "Ketaatan Malaikat", group: "Akidah" },
      { title: "Panduan Daripada Allah", group: "Akidah" },
      { title: "Solat Berjemaah Pengikat Hati", group: "Fekah" },
      { title: "Solat Jumaat Wadah Kesatuan", group: "Fekah" },
      { title: "Tayammum dengan Debu Suci", group: "Fekah" },
      { title: "Rukhsah Anugerah Daripada Allah", group: "Fekah" },
      { title: "Puasa Benteng Diri", group: "Fekah" },
      { title: "Solat Sunat Menampung Kefardhuan", group: "Fekah" },
      { title: "Terbitnya Fajar Dakwah", group: "Sirah" },
      { title: "Hijrah Detik Bersejarah", group: "Sirah" },
      { title: "Kepimpinan Rasulullah SAW di Madinah", group: "Sirah" },
      { title: "Wanita Suri Teladan Ummah", group: "Sirah" },
      { title: "Malu Perisai Iman", group: "Akhlak Islamiah" },
      { title: "Menyemai Kasih Menuai Sayang", group: "Akhlak Islamiah" },
      {
        title: "Muliakan Ibu Bapa Bahagiakan Keluarga",
        group: "Akhlak Islamiah",
      },
      { title: "Santuni Jiranmu", group: "Akhlak Islamiah" },
      { title: "Masjid Destinasiku", group: "Akhlak Islamiah" },
    ]),
  },
  {
    subjectKey: "pendidikanJasmani",
    firestoreSubjectId: "pjk",
    curriculum: "KSSM",
    form: 2,
    structureType: "unit",
    structureLabelSingular: "Unit",
    structureLabelPlural: "Units",
    curriculumSource: "KSSM Form 2 Pendidikan Jasmani dan Pendidikan Kesihatan textbook",
    curriculumSourceNote:
      "Textbook contents pages iii-iv and introduction page v: https://fliphtml5.com/iihhs/krbd/Pendidikan_Jasmani_dan_Pendidikan_Kesihatan_Tingkatan_2/; Ministry-linked textbook library: https://sites.google.com/moe-dl.edu.my/bidang-kemanusiaan-sebaru/panitia-pendidikan-jasmani-dan-kesihatan/buku-teks-digital. Eight PJ units followed by three PK units, with numbering restarting in PK. Textbook Unit labels are distinct from DSKP Standard Kandungan and Standard Pembelajaran codes.",
    items: draftPjkUnits(),
  },
  {
    subjectKey: "seni",
    firestoreSubjectId: "seni",
    curriculum: "KSSM",
    form: 2,
    structureType: "topic",
    structureLabelSingular: "Topic",
    structureLabelPlural: "Topics",
    curriculumSource: "KSSM Form 2 Pendidikan Seni Visual textbook",
    curriculumSourceNote:
      "Tajuk sequence cross-checked against the textbook contents in the Ministry-linked digital textbook library: https://sites.google.com/moe-dl.edu.my/bidang-kemanusiaan-sebaru/panitia-pendidikan-seni/buku-teks-digital.",
    items: draftSeniTopics([
      "Seni Ragam Hias Pengangkutan, Alat Permainan Rakyat dan Alat Domestik",
      "Seni Lukisan",
      "Seni Catan",
      "Seni Cetakan",
      "Reka Bentuk Landskap",
      "Reka Bentuk Hiasan Dalaman",
      "Reka Bentuk Industri",
      "Seni Sulaman",
      "Seni Seramik",
      "Seni Reka Grafik (Simbol dan Logo)",
      "Seni Foto",
    ]),
  },
];

export type CurriculumStructureLabels = Pick<
  CurriculumMetadata,
  "structureType" | "structureLabelSingular" | "structureLabelPlural"
>;

export function getForm2Curriculum(
  firestoreSubjectId: string,
): Form2Curriculum | undefined {
  return form2Curriculum.find(
    (subject) => subject.firestoreSubjectId === firestoreSubjectId,
  );
}

export function getCurriculumStructureLabels(
  firestoreSubjectId: string,
): CurriculumStructureLabels | undefined {
  const curriculum = getForm2Curriculum(firestoreSubjectId);
  if (!curriculum) return undefined;

  return {
    structureType: curriculum.structureType,
    structureLabelSingular: curriculum.structureLabelSingular,
    structureLabelPlural: curriculum.structureLabelPlural,
  };
}
